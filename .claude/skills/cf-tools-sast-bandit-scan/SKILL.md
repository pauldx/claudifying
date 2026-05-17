---
name: cf-tools-sast-bandit-scan
description: "Python SAST scanner via bandit — recursive static analysis with severity table + JSON output. Trigger: /cf-tools-sast-bandit-scan"
trigger: /cf-tools-sast-bandit-scan
version: 1.0.0
---

# /cf-tools-sast-bandit-scan

Targeted Python static-analysis security scan using [bandit](https://github.com/PyCQA/bandit). This skill is a **scanner-specific wrapper** — it runs one tool, parses JSON output, and reports findings in a deterministic shape. For multi-pass holistic review use `/cf-security-audit`.

## Usage

```
/cf-tools-sast-bandit-scan                              # scan src/ (or auto-detect package dir)
/cf-tools-sast-bandit-scan path/to/code                 # scan a specific path
/cf-tools-sast-bandit-scan path --skip B404,B603        # skip specific test IDs
/cf-tools-sast-bandit-scan path --baseline base.json    # diff vs baseline file
/cf-tools-sast-bandit-scan path --ci                    # exit non-zero on HIGH severity (CI mode)
```

Arguments:
1. `target-path` (optional, default `src/` or detected package) — directory to scan recursively
2. `--skip B-IDS` (optional) — comma-separated bandit test IDs to suppress (common: `B404,B603`)
3. `--baseline FILE` (optional) — bandit baseline JSON; only new findings are reported
4. `--ci` (optional) — exit code 1 if HIGH severity findings exist (use in CI pipelines)
5. `--json-out PATH` (optional, default `./bandit-report.json`) — JSON output path

## What You Must Do When Invoked

### Step 1 — Preflight: verify bandit is installed

```bash
if ! command -v bandit >/dev/null 2>&1; then
  echo "ERROR: bandit not installed."
  echo ""
  echo "Install via pipx (recommended, isolated):"
  echo "  pipx install bandit"
  echo ""
  echo "Or via pip:"
  echo "  pip install --user bandit"
  echo ""
  echo "Verify:"
  echo "  command -v bandit && bandit --version"
  exit 2
fi
echo "bandit: $(bandit --version 2>&1 | head -1)"
```

### Step 2 — Resolve target path

```bash
TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  for candidate in src lib app .; do
    if [ -d "$candidate" ] && find "$candidate" -maxdepth 3 -name '*.py' -print -quit | grep -q .; then
      TARGET="$candidate"
      break
    fi
  done
fi

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target path '$TARGET' is not a directory."
  exit 1
fi
echo "Scanning: $TARGET"
```

### Step 3 — Run bandit and capture JSON

```bash
JSON_OUT="${JSON_OUT:-./bandit-report.json}"
SKIP_FLAG=""
[ -n "$SKIP_IDS" ] && SKIP_FLAG="--skip $SKIP_IDS"

BASELINE_FLAG=""
[ -n "$BASELINE" ] && [ -f "$BASELINE" ] && BASELINE_FLAG="--baseline $BASELINE"

bandit -r "$TARGET" \
  -f json -o "$JSON_OUT" \
  $SKIP_FLAG $BASELINE_FLAG \
  --quiet || true   # bandit returns non-zero on findings; we parse JSON ourselves

if [ ! -s "$JSON_OUT" ]; then
  echo "ERROR: bandit produced no JSON output (scan may have aborted)."
  exit 1
fi
```

### Step 4 — Parse and tabulate

Use Python to summarize the JSON (bandit's output is well-defined):

```bash
python3 - "$JSON_OUT" <<'PY'
import json, sys, collections
data = json.load(open(sys.argv[1]))
results = data.get("results", [])
sev_counts = collections.Counter()
conf_counts = collections.Counter()
for r in results:
    sev_counts[r["issue_severity"]] += 1
    conf_counts[r["issue_confidence"]] += 1

print("\n## Severity counts")
for s in ("HIGH", "MEDIUM", "LOW"):
    print(f"  {s:7}: {sev_counts.get(s, 0)}")

print("\n## Confidence counts")
for c in ("HIGH", "MEDIUM", "LOW"):
    print(f"  {c:7}: {conf_counts.get(c, 0)}")

# Top 5 by severity then confidence
order = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
results.sort(key=lambda r: (order[r["issue_severity"]], order[r["issue_confidence"]]))
print("\n## Top 5 findings")
for i, r in enumerate(results[:5], 1):
    print(f"{i}. [{r['issue_severity']}/{r['issue_confidence']}] {r['test_id']} {r['test_name']}")
    print(f"   {r['filename']}:{r['line_number']}")
    print(f"   {r['issue_text'][:120]}")
PY
```

### Step 5 — CI gate (optional)

```bash
if [ "$CI_MODE" = "1" ]; then
  HIGH=$(python3 -c "import json,sys;d=json.load(open('$JSON_OUT'));print(sum(1 for r in d.get('results',[]) if r['issue_severity']=='HIGH'))")
  if [ "$HIGH" -gt 0 ]; then
    echo "CI FAIL: $HIGH HIGH-severity finding(s)."
    exit 1
  fi
fi
```

## Output Contract

```
## bandit SAST scan

**Target:**     <path>
**Files:**      <N> .py scanned
**JSON:**       <abs path to bandit-report.json>
**Runtime:**    <seconds>

## Severity counts
  HIGH:   <n>
  MEDIUM: <n>
  LOW:    <n>

## Top 5 findings
1. [SEV/CONF] B### test_name
   path/file.py:LINE
   <issue text>
...

CI gate: ✅ pass | ❌ fail (X HIGH findings)
```

## Config File

Bandit reads `.bandit` (INI) or `pyproject.toml` `[tool.bandit]` section from the **project root or scanned dir**. Common entries:

```ini
# .bandit
[bandit]
skips = B404,B603
exclude_dirs = ['tests', 'venv', '.venv']
```

Or in `pyproject.toml`:
```toml
[tool.bandit]
skips = ["B404", "B603"]
exclude_dirs = ["tests", "venv"]
```

If a config file exists, **do not override** with `--skip` unless the user explicitly asks.

## Gotchas

- **B404 / B603**: `subprocess` import + call. Very common false-positives in tooling code. Skip these unless the project takes untrusted input via subprocess args.
- **B101**: `assert` usage. Will flood test directories — always exclude `tests/` via config.
- **Baseline diff requires identical paths**: bandit's `--baseline` compares by file+line+test_id. Refactors will appear as "new" findings.
- **Exit code overload**: bandit exits 1 on *any* finding, regardless of severity. We ignore its exit code and gate manually on HIGH count for `--ci`.
- **JSON output is sparse on empty scans**: an empty `results` array is normal; do not treat it as failure.
- **Virtualenvs**: never scan `venv/`, `.venv/`, or `site-packages` — false-positive avalanche. Always exclude.
- **Encoding errors**: bandit chokes on non-UTF-8 Python files (rare). Re-encode or exclude.

## Cross-Platform Notes

- **macOS / Linux**: `pipx install bandit` is the cleanest install. `pipx ensurepath` to expose on `PATH`.
- **Windows**: `pip install --user bandit`; binary lands in `%APPDATA%\Python\Scripts\` — add to PATH.
- **CI containers**: use the official `pipx` install or `pip install bandit==<pinned-version>` in the job step. Pin the version to keep severity counts stable across runs.
