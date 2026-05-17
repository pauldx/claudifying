---
name: cf-tools-sast-trivy-scan
description: "Container & filesystem CVE scan via trivy — OS packages, language deps, IaC misconfig, secrets. Trigger: /cf-tools-sast-trivy-scan"
trigger: /cf-tools-sast-trivy-scan
version: 1.0.0
---

# /cf-tools-sast-trivy-scan

Vulnerability + misconfiguration scan via [trivy](https://github.com/aquasecurity/trivy). Covers OS packages, language deps (npm, pip, go modules, etc.), Dockerfile/k8s/terraform misconfig, and committed secrets. Single-tool wrapper — for layered code review use `/cf-security-audit`.

## Usage

```
/cf-tools-sast-trivy-scan                              # trivy fs . (filesystem scan)
/cf-tools-sast-trivy-scan fs path                      # filesystem mode on a path
/cf-tools-sast-trivy-scan image my-app:latest          # image mode
/cf-tools-sast-trivy-scan image my-app:latest --severity HIGH,CRITICAL
/cf-tools-sast-trivy-scan fs . --scanners vuln,secret,misconfig
/cf-tools-sast-trivy-scan fs . --ci                    # exit non-zero on HIGH/CRITICAL
```

Arguments:
1. `mode` (optional, default `fs`) — `fs` (filesystem) or `image` (container image)
2. `target` (positional) — path for `fs`, image ref for `image`
3. `--severity LIST` (optional, default `HIGH,CRITICAL`) — comma-separated: `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL`
4. `--scanners LIST` (optional, default `vuln,secret,misconfig`) — which scanners to run
5. `--ci` — exit 1 if any matching-severity finding exists
6. `--json-out PATH` (optional, default `./trivy-report.json`)

## What You Must Do When Invoked

### Step 1 — Preflight: verify trivy

```bash
if ! command -v trivy >/dev/null 2>&1; then
  echo "ERROR: trivy not installed."
  echo ""
  echo "Install via Homebrew (macOS):"
  echo "  brew install trivy"
  echo ""
  echo "Or via install script:"
  echo "  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
  echo ""
  echo "Or via Docker:"
  echo "  docker run --rm -v \"\$PWD:/src\" aquasec/trivy fs /src"
  echo ""
  echo "Verify:"
  echo "  command -v trivy && trivy --version"
  exit 2
fi
echo "trivy: $(trivy --version 2>&1 | head -1)"
```

### Step 2 — Resolve mode + target

```bash
MODE="${MODE:-fs}"
case "$MODE" in
  fs)    TARGET="${TARGET:-.}";;
  image) [ -z "$TARGET" ] && { echo "ERROR: image mode requires an image ref."; exit 1; };;
  *)     echo "ERROR: mode must be 'fs' or 'image' (got '$MODE')"; exit 1;;
esac

SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
SCANNERS="${SCANNERS:-vuln,secret,misconfig}"
JSON_OUT="${JSON_OUT:-./trivy-report.json}"

echo "Mode:       $MODE"
echo "Target:     $TARGET"
echo "Severity:   $SEVERITY"
echo "Scanners:   $SCANNERS"
```

### Step 3 — Run trivy

```bash
# --exit-code 0: never fail on findings; we gate manually
# --quiet: suppress progress bar
# --timeout: bump for large images
# --cache-dir: use default; trivy caches the vuln DB

trivy "$MODE" "$TARGET" \
  --severity "$SEVERITY" \
  --scanners "$SCANNERS" \
  --format json \
  --output "$JSON_OUT" \
  --quiet \
  --timeout 10m \
  --exit-code 0

if [ ! -s "$JSON_OUT" ]; then
  echo "ERROR: trivy produced no JSON output."
  exit 1
fi
```

### Step 4 — Parse + tabulate

Trivy's JSON shape: top-level `Results[]`, each with `Vulnerabilities[]`, `Misconfigurations[]`, `Secrets[]`.

```bash
python3 - "$JSON_OUT" <<'PY'
import json, sys, collections
data = json.load(open(sys.argv[1]))
results = data.get("Results", []) or []

vuln_sev = collections.Counter()
misc_sev = collections.Counter()
secret_sev = collections.Counter()

all_vulns, all_misc, all_secrets = [], [], []

for r in results:
    target = r.get("Target", "?")
    for v in r.get("Vulnerabilities", []) or []:
        vuln_sev[v["Severity"]] += 1
        all_vulns.append((v["Severity"], v["VulnerabilityID"], v.get("PkgName", ""),
                          v.get("InstalledVersion", ""), v.get("FixedVersion", "n/a"), target))
    for m in r.get("Misconfigurations", []) or []:
        misc_sev[m["Severity"]] += 1
        all_misc.append((m["Severity"], m["ID"], m.get("Title", ""), target))
    for s in r.get("Secrets", []) or []:
        secret_sev[s["Severity"]] += 1
        all_secrets.append((s["Severity"], s.get("RuleID", "?"), s.get("Title", ""),
                            target, s.get("StartLine", 0)))

order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "UNKNOWN": 4}

print("\n## Severity counts")
print("  Vulnerabilities:")
for s in ("CRITICAL", "HIGH", "MEDIUM", "LOW"):
    print(f"    {s:9}: {vuln_sev.get(s, 0)}")
print("  Misconfigurations:")
for s in ("CRITICAL", "HIGH", "MEDIUM", "LOW"):
    print(f"    {s:9}: {misc_sev.get(s, 0)}")
print("  Secrets:")
for s in ("CRITICAL", "HIGH", "MEDIUM", "LOW"):
    print(f"    {s:9}: {secret_sev.get(s, 0)}")

# Top 5 by severity across all categories
all_vulns.sort(key=lambda x: order.get(x[0], 9))
print("\n## Top 5 vulnerabilities")
for i, v in enumerate(all_vulns[:5], 1):
    sev, vid, pkg, iv, fv, tgt = v
    print(f"{i}. [{sev}] {vid} in {pkg} {iv} (fixed: {fv})")
    print(f"   target: {tgt}")

if all_secrets:
    print("\n## Top 3 secret findings")
    all_secrets.sort(key=lambda x: order.get(x[0], 9))
    for i, s in enumerate(all_secrets[:3], 1):
        print(f"{i}. [{s[0]}] {s[1]} {s[2]}")
        print(f"   {s[3]}:{s[4]}")
PY
```

### Step 5 — CI gate

```bash
if [ "$CI_MODE" = "1" ]; then
  CRIT=$(python3 -c "
import json
d=json.load(open('$JSON_OUT'))
n=0
for r in d.get('Results',[]) or []:
    for v in (r.get('Vulnerabilities') or []) + (r.get('Misconfigurations') or []) + (r.get('Secrets') or []):
        if v.get('Severity') in ('HIGH','CRITICAL'): n+=1
print(n)")
  if [ "$CRIT" -gt 0 ]; then
    echo "CI FAIL: $CRIT HIGH/CRITICAL finding(s)."
    exit 1
  fi
fi
```

## Output Contract

```
## trivy <fs|image> scan

**Mode:**       <fs|image>
**Target:**     <path or image ref>
**Severity:**   <filter list>
**Scanners:**   <vuln,secret,misconfig>
**JSON:**       <abs path>
**Runtime:**    <seconds>

## Severity counts
  Vulnerabilities:
    CRITICAL: <n>
    HIGH:     <n>
    MEDIUM:   <n>
    LOW:      <n>
  Misconfigurations: ...
  Secrets: ...

## Top 5 vulnerabilities
1. [CRITICAL] CVE-2024-XXXXX in openssl 3.0.10 (fixed: 3.0.13)
   target: alpine:3.18 (alpine)
...

## Top 3 secret findings (if any)
1. [HIGH] aws-access-token AWS Access Key
   src/config.js:12

CI gate: ✅ pass | ❌ fail (X HIGH/CRITICAL findings)
```

## Config File

- `.trivyignore` — list CVE IDs to suppress, one per line (e.g. `CVE-2024-12345`).
- `trivy.yaml` — full config (severity defaults, scanner toggles, cache dir).
- `.trivyignore.yaml` — newer structured ignore with expiration dates and reasons.

Example `.trivyignore`:
```
# Suppressed: low-risk in our threat model, fix scheduled Q2
CVE-2024-12345
# False positive, dependency not actually exposed
CVE-2024-67890
```

## Gotchas

- **First run downloads vuln DB** (~600MB). Subsequent runs cache. In CI, mount/persist `~/.cache/trivy` between jobs.
- **DB updates daily**: findings can shift between runs. Pin `--db-repository` and `--skip-db-update` for reproducible CI.
- **Image scan needs the image present**: trivy pulls if remote, or reads local docker. For private registries, set `DOCKER_CONFIG` to a dir with `config.json` containing creds.
- **fs mode misses container-only deps**: `trivy fs` scans lockfiles; `trivy image` also scans OS packages installed in the layer.
- **Secrets scanner false positives**: high-entropy strings in test fixtures. Use `.trivyignore` with the rule ID + path.
- **Misconfig scope**: trivy reads Dockerfiles, k8s manifests, terraform plans, helm charts. If you have IaC, this is the most useful scanner.
- **No license scan by default**: add `--scanners license` if needed (separate concern from security).
- **JSON is huge on large images**: a base alpine image can hit thousands of vulns. The `--severity HIGH,CRITICAL` filter is essential.

## Cross-Platform Notes

- **macOS**: `brew install trivy`. Apple Silicon native.
- **Linux**: install script writes to `/usr/local/bin` by default. APT/YUM repos available from aquasec.
- **Windows**: choco install trivy, or use WSL2.
- **CI**: official Docker image `aquasec/trivy` — mount workspace and cache dir. GitHub Action `aquasecurity/trivy-action` wraps it.
