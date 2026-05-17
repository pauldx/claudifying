---
name: cf-tools-data-csv-to-json
description: "Convert CSV file to a JSON array of objects. Trigger: /cf-tools-data-csv-to-json"
trigger: /cf-tools-data-csv-to-json
version: 1.0.0
---

# /cf-tools-data-csv-to-json

Convert any CSV file into a JSON array of objects. First row is treated as the header. Output is pretty-printed by default, compact with `--compact`. Auto-infers numeric/boolean types unless `--strings` is passed.

## Usage

```
/cf-tools-data-csv-to-json data.csv
/cf-tools-data-csv-to-json data.csv --compact
/cf-tools-data-csv-to-json data.csv --strings --output out.json
/cf-tools-data-csv-to-json data.tsv --delim tab
```

Arguments:
1. `csv-path` (required) — source CSV (or TSV)
2. `--compact` (optional) — one-line JSON output
3. `--strings` (optional) — keep all values as strings (skip type inference)
4. `--output PATH` (optional) — write to file instead of stdout
5. `--delim TAB|,|;` (optional, default `,`) — field delimiter

## Why miller (mlr) first

| Tool | Type inference | Header | Streaming | Available |
|---|---|---|---|---|
| `mlr --c2j` | ✅ auto numeric | ✅ | ✅ | `brew install miller` |
| Python `csv.DictReader` + `json` | ⚠️ manual | ✅ | ✅ | stdlib (always) |
| `jq -R -s` one-liner | ⚠️ brittle on quoting | ⚠️ manual | ❌ | always (if jq installed) |

mlr handles RFC 4180 quoting correctly. Python fallback ships with every macOS/Linux box.

## What You Must Do When Invoked

### Step 1 — Validate input

```bash
CSV="$1"
[ -f "$CSV" ] || { echo "ERROR: not found: $CSV"; exit 1; }
COMPACT=false; STRINGS=false; OUT=""; DELIM=","
# parse flags from "$@" — --compact, --strings, --output, --delim
```

### Step 2 — Prefer mlr

```bash
if command -v mlr >/dev/null 2>&1; then
  FMT="--c2j"
  [ "$DELIM" = "tab" ] && FMT="--t2j"
  if $COMPACT; then
    OUTPUT=$(mlr $FMT --jvquoteall=false cat "$CSV" | jq -c . 2>/dev/null || mlr $FMT cat "$CSV")
  else
    OUTPUT=$(mlr $FMT cat "$CSV")
  fi
fi
```

### Step 3 — Python stdlib fallback

```bash
if [ -z "$OUTPUT" ]; then
OUTPUT=$(python3 - "$CSV" "$DELIM" "$STRINGS" <<'PY'
import csv, json, sys
path, delim, strings = sys.argv[1], sys.argv[2], sys.argv[3] == "True"
delim = "\t" if delim == "tab" else delim
def coerce(v):
    if strings: return v
    if v == "": return None
    if v.lower() in ("true","false"): return v.lower() == "true"
    try: return int(v)
    except: pass
    try: return float(v)
    except: return v
with open(path, newline="") as f:
    rows = [{k: coerce(v) for k, v in r.items()} for r in csv.DictReader(f, delimiter=delim)]
print(json.dumps(rows, indent=None if False else 2, ensure_ascii=False))
PY
)
fi
```

### Step 4 — Write or print

```bash
if [ -n "$OUT" ]; then
  echo "$OUTPUT" > "$OUT"
  echo "✅ Wrote $(echo "$OUTPUT" | jq 'length' 2>/dev/null) rows → $OUT"
else
  echo "$OUTPUT"
fi
```

## Output Contract

```
## CSV → JSON conversion

**Source:**  data.csv
**Output:**  out.json (or stdout)
**Rows:**    <N>
**Method:**  miller | python-stdlib
**Types:**   auto-inferred | strings-only
```

## Gotchas

- **Numbers as strings**: pass `--strings` if leading-zero IDs ("007") must be preserved.
- **Empty cells**: become `null` in Python fallback, `""` in mlr. Use `--strings` for consistent `""`.
- **CRLF line endings**: mlr handles them; Python `csv` module handles them when opened with `newline=""`.
- **Quoted commas**: only safe with mlr or `csv.DictReader` — never split on `,` manually.
- **BOM in header**: strip with `sed '1s/^\xEF\xBB\xBF//' file.csv` before piping.
- **Huge files**: pipe to `mlr --c2jl` (JSON lines) for streaming instead of one giant array.

## Cross-Platform Notes

- **macOS**: `brew install miller` for mlr. Python 3 preinstalled.
- **Linux**: `apt install miller` or `dnf install miller`.
- **Windows / WSL**: WSL recommended for path handling; otherwise install miller via `choco install miller`.
