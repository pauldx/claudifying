---
name: cf-tools-sast-gosec-scan
description: "Go SAST via gosec — scans for unsafe imports, hardcoded creds, weak crypto, unchecked errors. Trigger: /cf-tools-sast-gosec-scan"
trigger: /cf-tools-sast-gosec-scan
version: 1.0.0
---

# /cf-tools-sast-gosec-scan

Go-only static analysis via [gosec](https://github.com/securego/gosec). Wraps a single tool — for broader review use `/cf-security-audit`.

## Usage

```
/cf-tools-sast-gosec-scan                            # scan ./... from CWD
/cf-tools-sast-gosec-scan ./pkg/...                  # scan a specific Go package pattern
/cf-tools-sast-gosec-scan ./... --severity HIGH      # only HIGH severity
/cf-tools-sast-gosec-scan ./... --confidence HIGH    # only HIGH confidence
/cf-tools-sast-gosec-scan ./... --exclude G104,G304  # skip rule IDs
/cf-tools-sast-gosec-scan ./... --ci                 # exit non-zero on HIGH+HIGH findings
```

Arguments:
1. `package-pattern` (optional, default `./...`) — Go package selector
2. `--severity LEVEL` (optional, default `HIGH`) — `LOW`, `MEDIUM`, `HIGH`
3. `--confidence LEVEL` (optional, default `HIGH`) — `LOW`, `MEDIUM`, `HIGH`
4. `--exclude IDS` (optional) — comma-separated gosec rule IDs to skip (e.g. `G104,G304`)
5. `--ci` — exit 1 if any HIGH-severity + HIGH-confidence finding exists
6. `--json-out PATH` (optional, default `./gosec-report.json`)

## What You Must Do When Invoked

### Step 1 — Preflight: verify gosec + go.mod

```bash
if ! command -v gosec >/dev/null 2>&1; then
  echo "ERROR: gosec not installed."
  echo ""
  echo "Install via Homebrew (macOS):"
  echo "  brew install gosec"
  echo ""
  echo "Or via go install:"
  echo "  go install github.com/securego/gosec/v2/cmd/gosec@latest"
  echo ""
  echo "Or via curl install script:"
  echo "  curl -sfL https://raw.githubusercontent.com/securego/gosec/master/install.sh | sh -s -- -b \$(go env GOPATH)/bin"
  echo ""
  echo "Verify:"
  echo "  command -v gosec && gosec --version"
  exit 2
fi

if [ ! -f go.mod ]; then
  echo "ERROR: no go.mod in current directory. gosec needs a Go module root."
  echo "cd to your project root or pass a package pattern that resolves to one."
  exit 1
fi

echo "gosec: $(gosec --version 2>&1 | head -1)"
echo "go.mod: $(grep '^module' go.mod | head -1)"
```

### Step 2 — Build flag set

```bash
PATTERN="${1:-./...}"
SEVERITY="${SEVERITY:-high}"           # gosec uses lowercase
CONFIDENCE="${CONFIDENCE:-high}"
JSON_OUT="${JSON_OUT:-./gosec-report.json}"

EXCLUDE_FLAG=""
[ -n "$EXCLUDE_IDS" ] && EXCLUDE_FLAG="-exclude=$EXCLUDE_IDS"
```

### Step 3 — Run gosec

```bash
# -fmt=json: machine-readable output
# -out: write to file (avoids piping issues with large reports)
# -severity / -confidence: filters at scan time
# -no-fail: keep gosec from exiting non-zero; we gate manually for --ci

gosec \
  -fmt=json \
  -out="$JSON_OUT" \
  -severity="$SEVERITY" \
  -confidence="$CONFIDENCE" \
  $EXCLUDE_FLAG \
  -quiet \
  -no-fail \
  "$PATTERN"

if [ ! -s "$JSON_OUT" ]; then
  echo "ERROR: gosec produced no JSON output."
  exit 1
fi
```

### Step 4 — Parse + tabulate

```bash
python3 - "$JSON_OUT" <<'PY'
import json, sys, collections
data = json.load(open(sys.argv[1]))
issues = data.get("Issues", [])
stats = data.get("Stats", {})

sev = collections.Counter(i["severity"] for i in issues)
conf = collections.Counter(i["confidence"] for i in issues)

print(f"\n## Scan stats")
print(f"  Files:  {stats.get('files', '?')}")
print(f"  Lines:  {stats.get('lines', '?')}")
print(f"  Nosec:  {stats.get('nosec', 0)} (suppressions)")

print("\n## Severity counts")
for s in ("HIGH", "MEDIUM", "LOW"):
    print(f"  {s:7}: {sev.get(s, 0)}")

print("\n## Confidence counts")
for c in ("HIGH", "MEDIUM", "LOW"):
    print(f"  {c:7}: {conf.get(c, 0)}")

order = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
issues.sort(key=lambda i: (order[i["severity"]], order[i["confidence"]]))
print("\n## Top 5 findings")
for i, x in enumerate(issues[:5], 1):
    print(f"{i}. [{x['severity']}/{x['confidence']}] {x['rule_id']} {x['details']}")
    print(f"   {x['file']}:{x['line']}")
    print(f"   {x.get('code', '').strip()[:120]}")
PY
```

### Step 5 — CI gate

```bash
if [ "$CI_MODE" = "1" ]; then
  CRIT=$(python3 -c "import json;d=json.load(open('$JSON_OUT'));print(sum(1 for i in d.get('Issues',[]) if i['severity']=='HIGH' and i['confidence']=='HIGH'))")
  if [ "$CRIT" -gt 0 ]; then
    echo "CI FAIL: $CRIT HIGH/HIGH finding(s)."
    exit 1
  fi
fi
```

## Output Contract

```
## gosec SAST scan

**Pattern:**    <./...>
**Module:**     <module path from go.mod>
**JSON:**       <abs path>
**Runtime:**    <seconds>

## Scan stats
  Files: <n>  Lines: <n>  Nosec suppressions: <n>

## Severity counts
  HIGH:   <n>
  MEDIUM: <n>
  LOW:    <n>

## Top 5 findings
1. [HIGH/HIGH] G304 Potential file inclusion via variable
   internal/router/handler.go:88
   <code snippet>
...

CI gate: ✅ pass | ❌ fail (X HIGH/HIGH findings)
```

## Config File

- `.gosec.yaml` (or `.gosec.json`) in project root.
- Specifies global ignored rules, audit mode flags, and per-rule config (e.g. allowed crypto algorithms).

Example `.gosec.yaml`:
```yaml
global:
  nosec: false
  audit: true
rules:
  G104:  # Errors not checked
    exclude:
      - "tests/"
  G304:  # Potential file inclusion via variable
    enabled: true
```

Pass via `-conf .gosec.yaml` if the user has one. Default skill behavior does not require it.

## Common Rule IDs (FYI)

- **G101** — Hardcoded credentials
- **G104** — Errors unchecked (very noisy; often excluded)
- **G304** — File inclusion via variable
- **G401/G402/G403** — Weak crypto (MD5, SHA1, weak TLS)
- **G501/G502** — Blocklisted imports (md5, des)
- **G601** — Implicit memory aliasing in range (irrelevant on Go 1.22+)

## Gotchas

- **G104 floods test code**: most projects exclude it. Add to `--exclude` or `.gosec.yaml`.
- **G601 obsolete on Go 1.22+**: range semantics changed; auto-exclude or upgrade gosec.
- **Vendored deps**: gosec scans `vendor/` by default. Pass `-exclude-dir=vendor` or set in config.
- **CGO files**: parse failures on `.go` files using cgo are reported as errors, not findings. Check the `Errors` field in JSON.
- **Generated code**: `//nolint:gosec` won't suppress, but `// #nosec` will. Cleaner to exclude paths via config.
- **GOFLAGS / build tags**: gosec respects `GOFLAGS`. If your project uses build tags, set them or scan misses files.
- **Memory on monorepos**: `./...` walks everything. Scope to `./internal/...` or `./pkg/...` for faster scans.

## Cross-Platform Notes

- **macOS**: `brew install gosec`. Apple Silicon native binary.
- **Linux**: install script or `go install ...@latest`. Make sure `$(go env GOPATH)/bin` is on PATH.
- **Windows**: `go install` works; binary lands in `%USERPROFILE%\go\bin\`.
- **CI**: official Docker image `securego/gosec` available; pin a tag for stable findings.
