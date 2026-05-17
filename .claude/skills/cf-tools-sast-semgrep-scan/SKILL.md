---
name: cf-tools-sast-semgrep-scan
description: "Polyglot SAST via semgrep — supports curated rulesets (auto, owasp-top-ten) across 30+ languages. Trigger: /cf-tools-sast-semgrep-scan"
trigger: /cf-tools-sast-semgrep-scan
version: 1.0.0
---

# /cf-tools-sast-semgrep-scan

Run [semgrep](https://semgrep.dev) static analysis with curated rulesets. Works across Python, JS/TS, Go, Java, Ruby, C, and more. This is a single-tool wrapper — for layered review use `/cf-security-audit`.

## Usage

```
/cf-tools-sast-semgrep-scan                              # scan . with --config auto
/cf-tools-sast-semgrep-scan path                         # scan a path
/cf-tools-sast-semgrep-scan path --config p/owasp-top-ten
/cf-tools-sast-semgrep-scan path --config p/python p/secrets   # multiple rulesets
/cf-tools-sast-semgrep-scan path --severity ERROR        # only ERROR severity
/cf-tools-sast-semgrep-scan path --ci                    # exit non-zero on ERROR findings
```

Arguments:
1. `target-path` (optional, default `.`) — directory to scan
2. `--config CONFIG` (optional, default `auto`) — semgrep config; can repeat. Common: `auto`, `p/owasp-top-ten`, `p/secrets`, `p/python`, `p/javascript`, `p/golang`, `p/cwe-top-25`
3. `--severity LEVEL` (optional) — filter to `ERROR`, `WARNING`, or `INFO` (default: all)
4. `--ci` — exit 1 if any ERROR-severity finding exists
5. `--json-out PATH` (optional, default `./semgrep-report.json`)

## What You Must Do When Invoked

### Step 1 — Preflight: verify semgrep

```bash
if ! command -v semgrep >/dev/null 2>&1; then
  echo "ERROR: semgrep not installed."
  echo ""
  echo "Install via pipx (recommended):"
  echo "  pipx install semgrep"
  echo ""
  echo "Or via Homebrew:"
  echo "  brew install semgrep"
  echo ""
  echo "Or via pip:"
  echo "  pip install --user semgrep"
  echo ""
  echo "Verify:"
  echo "  command -v semgrep && semgrep --version"
  exit 2
fi
echo "semgrep: $(semgrep --version 2>&1)"
```

### Step 2 — Build config args

```bash
TARGET="${TARGET:-.}"
CONFIGS=("${CONFIGS[@]:-auto}")    # array; default "auto"
JSON_OUT="${JSON_OUT:-./semgrep-report.json}"

CFG_FLAGS=()
for c in "${CONFIGS[@]}"; do
  CFG_FLAGS+=("--config" "$c")
done

SEV_FLAG=()
[ -n "$SEVERITY" ] && SEV_FLAG=("--severity" "$SEVERITY")
```

### Step 3 — Run semgrep

```bash
# --error: non-zero exit on findings. We disable this and gate manually for --ci.
# --metrics off: opt out of telemetry for offline / privacy-sensitive runs.
# --timeout 30: per-rule cap (semgrep default is 30s; explicit for clarity).

semgrep scan \
  "${CFG_FLAGS[@]}" \
  "${SEV_FLAG[@]}" \
  --json \
  --output "$JSON_OUT" \
  --metrics off \
  --timeout 30 \
  --quiet \
  "$TARGET" || true

if [ ! -s "$JSON_OUT" ]; then
  echo "ERROR: semgrep produced no JSON output."
  exit 1
fi
```

### Step 4 — Parse + tabulate

```bash
python3 - "$JSON_OUT" <<'PY'
import json, sys, collections
data = json.load(open(sys.argv[1]))
results = data.get("results", [])
errs = data.get("errors", [])

sev = collections.Counter(r["extra"]["severity"] for r in results)
print("\n## Severity counts")
for s in ("ERROR", "WARNING", "INFO"):
    print(f"  {s:8}: {sev.get(s, 0)}")

if errs:
    print(f"\n## Scanner errors: {len(errs)} (rule timeouts or parse failures)")

order = {"ERROR": 0, "WARNING": 1, "INFO": 2}
results.sort(key=lambda r: order.get(r["extra"]["severity"], 9))
print("\n## Top 5 findings")
for i, r in enumerate(results[:5], 1):
    s = r["extra"]["severity"]
    rid = r["check_id"]
    path = r["path"]
    line = r["start"]["line"]
    msg = r["extra"].get("message", "").strip().replace("\n", " ")
    print(f"{i}. [{s}] {rid}")
    print(f"   {path}:{line}")
    print(f"   {msg[:140]}")
PY
```

### Step 5 — CI gate

```bash
if [ "$CI_MODE" = "1" ]; then
  ERR=$(python3 -c "import json;d=json.load(open('$JSON_OUT'));print(sum(1 for r in d.get('results',[]) if r['extra']['severity']=='ERROR'))")
  if [ "$ERR" -gt 0 ]; then
    echo "CI FAIL: $ERR ERROR-severity finding(s)."
    exit 1
  fi
fi
```

## Output Contract

```
## semgrep SAST scan

**Target:**     <path>
**Configs:**    <list of rulesets>
**JSON:**       <abs path>
**Runtime:**    <seconds>

## Severity counts
  ERROR:   <n>
  WARNING: <n>
  INFO:    <n>

## Top 5 findings
1. [ERROR] python.lang.security.audit.subprocess-shell-true
   src/cli.py:42
   <message>
...

CI gate: ✅ pass | ❌ fail (X ERROR findings)
```

## Config File

- `.semgrep.yml` or `.semgrepignore` in project root.
- `.semgrepignore` uses gitignore syntax — exclude `tests/`, `vendor/`, `node_modules/`.
- For custom rules, drop YAML files under `.semgrep/` and add `--config .semgrep/` to args.

Example `.semgrepignore`:
```
node_modules/
vendor/
dist/
build/
*.min.js
```

## Gotchas

- **`--config auto` requires network**: it fetches latest community rules from semgrep.dev. For air-gapped runs, pre-cache via `semgrep --config auto --download-only` or pin to a specific ruleset like `p/owasp-top-ten`.
- **`--config auto` may opt-in to telemetry**: we pass `--metrics off` explicitly.
- **Login required for some registry rules**: free tier covers `p/` packs; pro packs need `semgrep login`. Skill defaults to free packs only.
- **Timeout on large repos**: default per-rule timeout is 30s. Bump via `--timeout 60` for monorepos. If many rules time out, scope to a subdirectory.
- **`.semgrepignore` is separate from `.gitignore`**: semgrep does NOT auto-honor `.gitignore` for some commands. Always add a `.semgrepignore`.
- **Severity is per-rule, not per-finding**: changing rule severity requires editing the rule YAML or using `--severity` to filter at output time.
- **Memory hog on huge JS files**: minified bundles cause OOM. Exclude `*.min.js` and `dist/`.

## Cross-Platform Notes

- **macOS**: `brew install semgrep` or `pipx install semgrep`. Apple Silicon supported natively.
- **Linux**: `pipx install semgrep` is the universal option. Static binaries available on releases page for some distros.
- **Windows**: official support is Linux/macOS only; on Windows use WSL2.
- **CI**: official Docker image `returntocorp/semgrep` is the simplest CI path. Pin a tag (e.g. `:1.x.y`) to keep findings stable.
