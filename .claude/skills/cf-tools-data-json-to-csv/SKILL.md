---
name: cf-tools-data-json-to-csv
description: "Convert a JSON array of objects into CSV with a header row. Trigger: /cf-tools-data-json-to-csv"
trigger: /cf-tools-data-json-to-csv
version: 1.0.0
---

# /cf-tools-data-json-to-csv

Convert a JSON array of objects into CSV. Header row is the union of keys from all objects. Nested values are JSON-stringified (or flattened with `--flatten`). Single-object input is wrapped to a 1-row CSV.

## Usage

```
/cf-tools-data-json-to-csv data.json
/cf-tools-data-json-to-csv data.json --output out.csv
/cf-tools-data-json-to-csv data.json --flatten
/cf-tools-data-json-to-csv data.json --columns name,age,city
/cf-tools-data-json-to-csv data.ndjson --ndjson
```

Arguments:
1. `json-path` (required)
2. `--output PATH` (optional) — default stdout
3. `--flatten` (optional) — flatten nested objects to dot keys (`a.b.c`)
4. `--columns a,b,c` (optional) — explicit column order; missing keys become empty
5. `--ndjson` (optional) — input is newline-delimited JSON (one obj per line)
6. `--delim ,|;|TAB` (optional, default `,`)

## Why miller (mlr) first

| Tool | Header union | Quoting | NDJSON | Available |
|---|---|---|---|---|
| `mlr --j2c` | ✅ | ✅ RFC 4180 | ✅ `--jl2c` | brew |
| Python `csv` + `json` | ✅ | ✅ | ✅ | stdlib |
| `jq -r '@csv'` | ⚠️ manual | ✅ | ✅ | always |

mlr's header union handles "sparse" objects (some have city, some don't) correctly. Manual jq requires explicit column lists.

## What You Must Do When Invoked

### Step 1 — Validate input

```bash
JSON="$1"
[ -f "$JSON" ] || { echo "ERROR: not found: $JSON"; exit 1; }
jq -e . "$JSON" >/dev/null 2>&1 || { echo "ERROR: invalid JSON"; exit 1; }
```

### Step 2 — Prefer mlr

```bash
if command -v mlr >/dev/null 2>&1; then
  FMT="--j2c"; $NDJSON && FMT="--jl2c"
  if $FLATTEN; then
    OUTPUT=$(mlr $FMT --jflatsep=. cat "$JSON")
  elif [ -n "$COLUMNS" ]; then
    OUTPUT=$(mlr $FMT cat then reorder -f "$COLUMNS" "$JSON")
  else
    OUTPUT=$(mlr $FMT cat "$JSON")
  fi
fi
```

### Step 3 — Python stdlib fallback

```bash
OUTPUT=$(python3 - "$JSON" "$NDJSON" "$FLATTEN" "$COLUMNS" "$DELIM" <<'PY'
import csv, json, sys, io
path, ndjson, flatten, cols, delim = sys.argv[1:]
ndjson = ndjson == "True"; flatten = flatten == "True"
delim = "\t" if delim == "TAB" else delim

def flat(d, p=""):
    out = {}
    if isinstance(d, dict):
        for k, v in d.items():
            out.update(flat(v, f"{p}.{k}" if p else k))
    elif isinstance(d, list):
        for i, v in enumerate(d):
            out.update(flat(v, f"{p}[{i}]"))
    else:
        out[p] = d
    return out

with open(path) as f:
    if ndjson:
        rows = [json.loads(l) for l in f if l.strip()]
    else:
        data = json.load(f)
        rows = data if isinstance(data, list) else [data]

if flatten:
    rows = [flat(r) for r in rows]
else:
    rows = [{k: (json.dumps(v) if isinstance(v, (dict, list)) else v) for k, v in r.items()} for r in rows]

if cols:
    header = cols.split(",")
else:
    header = []
    for r in rows:
        for k in r.keys():
            if k not in header: header.append(k)

buf = io.StringIO()
w = csv.DictWriter(buf, fieldnames=header, delimiter=delim, extrasaction="ignore")
w.writeheader()
for r in rows: w.writerow(r)
print(buf.getvalue(), end="")
PY
)
```

### Step 4 — Write or print

```bash
if [ -n "$OUT" ]; then
  printf '%s' "$OUTPUT" > "$OUT"
  echo "✅ Wrote $(echo "$OUTPUT" | tail -n +2 | wc -l) rows → $OUT"
else
  printf '%s' "$OUTPUT"
fi
```

## Output Contract

```
## JSON → CSV conversion

**Source:**   data.json
**Output:**   out.csv (or stdout)
**Rows:**     <N>
**Columns:**  <a,b,c>
**Method:**   miller | python-stdlib
**Nested:**   stringified | flattened
```

## Gotchas

- **Sparse keys**: row 1 has `city`, row 2 doesn't → empty cell, not error. Header is the union.
- **Nested arrays without `--flatten`**: become JSON strings inside a CSV cell. Watch quoting.
- **Single object input** (not array): wrap to `[obj]` automatically.
- **NDJSON vs JSON array**: use `--ndjson` for one-object-per-line. mlr auto-detects but Python fallback needs the flag.
- **Column order**: without `--columns`, mlr uses first-row key order. Pass `--columns` for stability.
- **Delimiter collision**: if data contains commas, switch to `--delim TAB` and write `.tsv`.

## Cross-Platform Notes

- **macOS / Linux**: `brew install miller` or `apt install miller`.
- **Windows / WSL**: use WSL for proper line-ending handling. mlr writes LF; convert with `unix2dos` if Excel chokes.
