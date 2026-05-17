---
name: cf-tools-data-json-query
description: "Query JSON with jq using friendly error messages and pretty defaults. Trigger: /cf-tools-data-json-query"
trigger: /cf-tools-data-json-query
version: 1.0.0
---

# /cf-tools-data-json-query

Run a jq query against a JSON file with cleaner error reporting and useful defaults: pretty-print on, sorted keys off, slurp off. Wrap common patterns (keys, length, first N, distinct) under named flags.

## Usage

```
/cf-tools-data-json-query data.json '.[] | .name'
/cf-tools-data-json-query data.json --keys
/cf-tools-data-json-query data.json --length
/cf-tools-data-json-query data.json --first 5
/cf-tools-data-json-query data.json --distinct .city
/cf-tools-data-json-query data.json '.[] | select(.age > 28)' --compact
/cf-tools-data-json-query data.ndjson '.name' --ndjson
```

Arguments:
1. `json-path` (required)
2. `query` (required unless using a named flag below) — jq expression
3. `--keys` — list top-level keys / array length
4. `--length` — print `length` of input
5. `--first N` — return first N items (works on arrays / object key-arrays)
6. `--distinct EXPR` — unique values of EXPR across the input
7. `--compact` — single-line output (jq `-c`)
8. `--raw` — raw string output (jq `-r`)
9. `--ndjson` — input is newline-delimited JSON
10. `--output PATH` — default stdout

## Why jq + a wrapper

jq syntax is powerful but error messages are cryptic:

```
$ jq '.[] | foo' data.json
jq: error (at data.json:1): Cannot index array with string "foo"
```

This skill catches common errors (typoed key, syntax error, file not found) and reformats:

```
✗ Query error: tried to access key "foo" on an array.
  Did you mean: '.[] | .foo'?
```

## What You Must Do When Invoked

### Step 1 — Validate

```bash
JSON="$1"; QUERY="${2:-.}"; shift 2 || true
[ -f "$JSON" ] || { echo "ERROR: not found: $JSON"; exit 1; }
jq -e . "$JSON" >/dev/null 2>&1 || { echo "ERROR: invalid JSON: $JSON"; exit 1; }
```

### Step 2 — Map named flags to jq expressions

```bash
case "$NAMED" in
  keys)     QUERY='if type == "object" then keys else length end' ;;
  length)   QUERY='length' ;;
  first)    QUERY=".[0:$N]" ;;
  distinct) QUERY="[.[] | $DEXPR] | unique" ;;
esac
```

### Step 3 — Run with friendly errors

```bash
FLAGS=""
$COMPACT && FLAGS+=" -c"
$RAW && FLAGS+=" -r"
$NDJSON && FLAGS+=" -c" # process line-by-line; user can drop if they want pretty

if $NDJSON; then
  OUTPUT=$(jq $FLAGS "$QUERY" "$JSON" 2>&1)
else
  OUTPUT=$(jq $FLAGS "$QUERY" "$JSON" 2>&1)
fi
EXIT=$?

if [ $EXIT -ne 0 ]; then
  # Friendly error translation
  case "$OUTPUT" in
    *"Cannot index array with string"*)
      KEY=$(echo "$OUTPUT" | grep -oE '"[^"]+"' | head -1)
      echo "✗ Tried to access key $KEY on an array."
      echo "  Try: '.[] | .${KEY//\"/}' to map over array elements."
      ;;
    *"Cannot index object with number"*)
      echo "✗ Tried to use a numeric index on an object."
      echo "  Use a key string: '.foo' or '.[\"key\"]'"
      ;;
    *"unexpected $end"* | *"syntax error"*)
      echo "✗ jq syntax error. Check matching brackets and quotes."
      echo "  Raw error: $OUTPUT"
      ;;
    *)
      echo "✗ jq error: $OUTPUT"
      ;;
  esac
  exit $EXIT
fi
```

### Step 4 — Write or print

```bash
if [ -n "$OUT" ]; then printf '%s\n' "$OUTPUT" > "$OUT"; else printf '%s\n' "$OUTPUT"; fi
LINES=$(echo "$OUTPUT" | grep -c '^.' || echo 0)
echo "✅ $LINES result(s)"
```

## Output Contract

Pretty by default:
```json
[
  "Alice",
  "Bob",
  "Carol"
]
```

Report:
```
## JSON query

**Source:**  data.json
**Query:**   '.[] | .name'  (or --keys / --first 5 / --distinct .city)
**Mode:**    single | ndjson
**Results:** <N>
**Output:**  out.json (or stdout)
**Method:**  jq <version>
```

## Gotchas

- **Quoting in shell**: single-quote jq queries to prevent shell expansion. `'.users[] | .name'` not `."users[]"`.
- **jq version**: this skill assumes jq 1.6+. `1.7+` adds `?` postfix and `pick`. Check `jq --version`.
- **NDJSON vs JSON array**: NDJSON requires `--ndjson` — jq processes each line as a separate doc. Without it, jq tries to parse the whole file as one JSON.
- **`--distinct` on objects**: `unique` compares by JSON equality, so `{"a":1}` and `{"a":1}` collapse — but `{"a":1,"b":2}` and `{"b":2,"a":1}` also collapse (jq normalizes). Beware key-order assumptions.
- **`--first` on objects**: doesn't make sense unless you've sliced into an array. Skill errors gracefully if input is an object.
- **Streaming huge files**: jq buffers full input. For 1GB+ JSON, use `jq --stream` manually (not exposed here).
- **Exit on no match**: jq's `select` filters out — empty output is still success. Add `--exit-on-empty` (jq 1.7+) to fail when no rows match.

## Cross-Platform Notes

- **macOS**: jq preinstalled on 10.15+. Else `brew install jq`.
- **Linux**: `apt install jq` / `dnf install jq`.
- **Windows / WSL**: `choco install jq` or use WSL.
