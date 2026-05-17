---
name: cf-tools-data-json-validate
description: "Validate a JSON document against a JSON Schema (draft-07 / 2020-12). Trigger: /cf-tools-data-json-validate"
trigger: /cf-tools-data-json-validate
version: 1.0.0
---

# /cf-tools-data-json-validate

Validate a JSON document against a JSON Schema. Reports every violation with JSON-pointer paths. Exit code is non-zero on failure (CI-friendly). Without `--schema`, performs syntax-only validation.

## Usage

```
/cf-tools-data-json-validate data.json --schema schema.json
/cf-tools-data-json-validate data.json                       # syntax only
/cf-tools-data-json-validate data.json --schema schema.json --first-error
/cf-tools-data-json-validate data.ndjson --ndjson --schema schema.json
```

Arguments:
1. `json-path` (required) — document to validate
2. `--schema PATH` (optional) — JSON Schema file
3. `--first-error` (optional) — stop at first violation (faster on big docs)
4. `--ndjson` (optional) — validate each line as a separate document
5. `--draft DRAFT` (optional) — `draft-07` (default) | `2020-12` | `2019-09`

## Why python jsonschema first

| Tool | Schema support | Error paths | Available |
|---|---|---|---|
| Python `jsonschema` lib | drafts 4/6/7/2019/2020 | ✅ JSON pointers | `pip install jsonschema` |
| `ajv-cli` (Node) | drafts 4–2020 | ✅ | `npm i -g ajv-cli` |
| `jq` | ❌ no schema support | — | n/a |
| `check-jsonschema` | drafts 7/2019/2020 | ✅ | `pip install check-jsonschema` |

`jsonschema` is the de-facto Python library. If not installed, suggest `pip install jsonschema` (or `pipx install check-jsonschema`).

## What You Must Do When Invoked

### Step 1 — Validate inputs

```bash
DOC="$1"
[ -f "$DOC" ] || { echo "ERROR: doc not found: $DOC"; exit 1; }
if [ -n "$SCHEMA" ]; then
  [ -f "$SCHEMA" ] || { echo "ERROR: schema not found: $SCHEMA"; exit 1; }
fi
```

### Step 2 — Syntax check (always)

```bash
if $NDJSON; then
  LINE=0
  while IFS= read -r ln; do
    LINE=$((LINE+1))
    [ -z "$ln" ] && continue
    echo "$ln" | jq -e . >/dev/null 2>&1 || { echo "✗ Line $LINE: invalid JSON syntax"; SYNTAX_ERR=1; }
  done < "$DOC"
else
  jq -e . "$DOC" >/dev/null 2>&1 || { echo "✗ Invalid JSON syntax"; exit 1; }
fi
[ "${SYNTAX_ERR:-0}" -eq 1 ] && exit 1
[ -z "$SCHEMA" ] && { echo "✅ JSON syntax valid"; exit 0; }
```

### Step 3 — Schema validation via Python

```bash
python3 - "$DOC" "$SCHEMA" "$NDJSON" "$FIRST_ONLY" "$DRAFT" <<'PY'
import json, sys
doc_path, schema_path, ndjson, first_only, draft = sys.argv[1:]
ndjson = ndjson == "True"; first_only = first_only == "True"

try:
    from jsonschema import Draft7Validator, Draft201909Validator, Draft202012Validator
except ImportError:
    print("ERROR: jsonschema not installed. Run: pip install jsonschema")
    sys.exit(2)

Validator = {
    "draft-07": Draft7Validator,
    "2019-09": Draft201909Validator,
    "2020-12": Draft202012Validator,
}.get(draft, Draft7Validator)

schema = json.load(open(schema_path))
v = Validator(schema)

def validate(doc, label=""):
    errors = list(v.iter_errors(doc))
    if not errors: return 0
    for e in errors:
        path = "/" + "/".join(str(p) for p in e.absolute_path) if e.absolute_path else "/"
        prefix = f"{label}: " if label else ""
        print(f"✗ {prefix}{path} — {e.message}")
        if first_only: break
    return len(errors)

total = 0
if ndjson:
    with open(doc_path) as f:
        for i, ln in enumerate(f, 1):
            ln = ln.strip()
            if not ln: continue
            try: data = json.loads(ln)
            except Exception as ex: print(f"✗ Line {i}: parse error: {ex}"); total += 1; continue
            total += validate(data, f"Line {i}")
            if first_only and total: break
else:
    total = validate(json.load(open(doc_path)))

if total == 0:
    print("✅ Document matches schema")
    sys.exit(0)
print(f"\n{total} violation(s)")
sys.exit(1)
PY
```

### Step 4 — Optional ajv-cli fallback

If `pip install jsonschema` is not possible and Node is available:

```bash
if command -v ajv >/dev/null 2>&1; then
  ajv validate -s "$SCHEMA" -d "$DOC" --errors=text
fi
```

## Output Contract

On success:
```
✅ Document matches schema
```

On failure:
```
✗ /users/1/age — 25 is not of type 'string'
✗ /users/2 — 'name' is a required property

2 violation(s)
```

Report (after run):
```
## JSON validation

**Document:** data.json
**Schema:**   schema.json (draft-07)
**Mode:**     single | ndjson
**Result:**   ✅ valid | ✗ <N> violations
**Method:**   python-jsonschema | ajv-cli
```

## Gotchas

- **Missing library**: `jsonschema` is NOT stdlib. Skill prints `pip install jsonschema` and exits 2 (distinguishable from validation failure).
- **Draft mismatch**: if your schema has `"$schema": "...2020-12..."` but you pass `--draft draft-07`, results may differ. Default to draft-07 only if schema doesn't declare its own.
- **`$ref` resolution**: external `$ref` URLs require network. For local refs, use `file://` URIs and pass `--schema` with absolute path.
- **NDJSON huge files**: validating 1M-line NDJSON in a tight loop is slow. Use `--first-error` for CI gating.
- **Exit codes**: 0 valid, 1 violations, 2 setup error (missing lib, missing file). Hook into CI: `set -e` will catch all.
- **Unicode in error messages**: paths use JSON pointer syntax — `/users/1/age` not `users[1].age`. Convert downstream if needed.
- **Schema syntax errors**: this skill validates the *document* against the *schema*. It does NOT validate the schema itself is well-formed JSON Schema. Use `check-jsonschema --check-metaschema` for that.

## Cross-Platform Notes

- **macOS / Linux**: `pip install jsonschema` (or `pipx install check-jsonschema` for a global CLI).
- **Windows / WSL**: same. PowerShell users: prefer WSL for shell pipelines.
- **Air-gapped**: bundle `jsonschema` wheel into an offline pip cache.
