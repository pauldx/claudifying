---
name: cf-tools-data-yaml-to-json
description: "Convert YAML to JSON or JSON to YAML round-trip. Trigger: /cf-tools-data-yaml-to-json"
trigger: /cf-tools-data-yaml-to-json
version: 1.0.0
---

# /cf-tools-data-yaml-to-json

Convert YAML to JSON, or JSON back to YAML with `--inverse`. Multi-document YAML (`---` separators) becomes a JSON array. Output is pretty by default; `--compact` produces minified JSON.

## Usage

```
/cf-tools-data-yaml-to-json config.yaml
/cf-tools-data-yaml-to-json config.yaml --output config.json
/cf-tools-data-yaml-to-json config.yaml --compact
/cf-tools-data-yaml-to-json multi.yaml          # multi-doc → JSON array
/cf-tools-data-yaml-to-json config.json --inverse --output config.yaml
```

Arguments:
1. `path` (required) — YAML (or JSON if `--inverse`)
2. `--inverse` (optional) — JSON → YAML
3. `--output PATH` (optional) — default stdout
4. `--compact` (optional) — single-line JSON
5. `--multi` (optional) — force multi-doc treatment even if only one `---` block

## Why yq (Mike Farah's go-yq) first

| Tool | Multi-doc | Round-trip | Comments preserved | Available |
|---|---|---|---|---|
| `yq` (go-yq / Mike Farah) | ✅ `yq -o json '.'` | ✅ | ⚠️ partial | `brew install yq` |
| `python-yq` (kislyuk fork) | ✅ | ✅ | ❌ | `pip install yq` |
| Python `pyyaml` + `json` | ✅ via `yaml.safe_load_all` | ✅ | ❌ | `pip install pyyaml` (preinstalled on macOS) |
| `python3 -c "import yaml,json"` | ✅ | ✅ | ❌ | stdlib-ish (pyyaml usually present) |

This skill uses **Mike Farah's yq** (the Go binary). The Python-based `yq` from kislyuk has different syntax — verify with `yq --version`.

## What You Must Do When Invoked

### Step 1 — Validate

```bash
SRC="$1"
[ -f "$SRC" ] || { echo "ERROR: not found: $SRC"; exit 1; }
```

### Step 2 — Detect yq flavor

```bash
YQ_BIN=""
if command -v yq >/dev/null 2>&1; then
  if yq --version 2>&1 | grep -qi "mikefarah\|github.com/mikefarah"; then
    YQ_BIN="yq"
  fi
fi
```

### Step 3a — YAML → JSON (default)

```bash
if ! $INVERSE; then
  if [ -n "$YQ_BIN" ]; then
    if $COMPACT; then
      OUTPUT=$($YQ_BIN -o=json -I=0 '.' "$SRC")
    else
      OUTPUT=$($YQ_BIN -o=json '.' "$SRC")
    fi
    # Multi-doc: yq emits multiple JSON docs separated by newlines. Wrap to array if >1.
    DOC_COUNT=$($YQ_BIN -o=json '.' "$SRC" | jq -s 'length')
    if [ "$DOC_COUNT" -gt 1 ]; then
      OUTPUT=$($YQ_BIN -o=json '.' "$SRC" | jq -s '.')
      $COMPACT && OUTPUT=$(echo "$OUTPUT" | jq -c .)
    fi
  else
    OUTPUT=$(python3 - "$SRC" "$COMPACT" <<'PY'
import json, sys, yaml
path, compact = sys.argv[1], sys.argv[2] == "True"
docs = list(yaml.safe_load_all(open(path)))
data = docs[0] if len(docs) == 1 else docs
print(json.dumps(data, indent=None if compact else 2, ensure_ascii=False))
PY
)
  fi
fi
```

### Step 3b — JSON → YAML (--inverse)

```bash
if $INVERSE; then
  jq -e . "$SRC" >/dev/null 2>&1 || { echo "ERROR: invalid JSON"; exit 1; }
  if [ -n "$YQ_BIN" ]; then
    OUTPUT=$($YQ_BIN -P -o=yaml '.' "$SRC")
  else
    OUTPUT=$(python3 - "$SRC" <<'PY'
import json, sys, yaml
data = json.load(open(sys.argv[1]))
print(yaml.safe_dump(data, default_flow_style=False, sort_keys=False), end="")
PY
)
  fi
fi
```

### Step 4 — Write or print

```bash
if [ -n "$OUT" ]; then printf '%s\n' "$OUTPUT" > "$OUT"; else printf '%s\n' "$OUTPUT"; fi
echo "✅ Converted $([ -n "$INVERSE" ] && echo 'JSON → YAML' || echo 'YAML → JSON') → $([ -n "$OUT" ] && echo "$OUT" || echo "stdout")"
```

## Output Contract

Input:
```yaml
users:
  - name: Alice
    age: 30
  - name: Bob
    age: 25
```

Output (default, pretty):
```json
{
  "users": [
    { "name": "Alice", "age": 30 },
    { "name": "Bob", "age": 25 }
  ]
}
```

Report:
```
## YAML ↔ JSON conversion

**Source:**    config.yaml
**Direction:** YAML→JSON | JSON→YAML
**Docs:**      <N> (multi-doc handled as array)
**Output:**    config.json (or stdout)
**Method:**    go-yq (Mike Farah) | python-pyyaml
```

## Gotchas

- **yq flavor mismatch**: `python-yq` (kislyuk) uses jq-style filters (`yq '.foo'` with quotes). go-yq uses its own DSL. This skill assumes go-yq. Check `yq --version`.
- **Comments**: neither go-yq nor pyyaml preserve comments in the YAML→JSON direction (JSON has no comments). On JSON→YAML, comments are gone forever.
- **Anchors and aliases** (`&foo`, `*foo`): go-yq resolves them on output; pyyaml's `safe_load` resolves too. Both produce expanded JSON — original anchors are not recoverable.
- **Multi-doc YAML**: go-yq emits multiple JSON documents (newline-separated). This skill detects and wraps to an array when count > 1. Pass `--multi` to force array wrap on single-doc input.
- **Tag types** (`!!str`, `!!int`): pyyaml's `safe_load` rejects custom tags. Use `yaml.unsafe_load` only on trusted input — but don't.
- **JSON → YAML key ordering**: go-yq preserves insertion order. pyyaml needs `sort_keys=False` (set by this skill) to match.
- **Booleans**: YAML's `yes/no/on/off` become real booleans in JSON. To keep as strings, quote them in YAML (`"yes"`).

## Cross-Platform Notes

- **macOS**: `brew install yq` installs the Mike Farah Go binary. Python `pyyaml` ships preinstalled with macOS Python 3.
- **Linux**: `snap install yq` for Mike Farah's version, or download from GitHub releases. `apt install yq` may install the kislyuk fork — verify.
- **Windows / WSL**: WSL recommended. `choco install yq` installs go-yq on Windows.
