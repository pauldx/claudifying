---
name: cf-tools-data-csv-filter
description: "Filter CSV rows by column value, regex, or numeric comparison. Trigger: /cf-tools-data-csv-filter"
trigger: /cf-tools-data-csv-filter
version: 1.0.0
---

# /cf-tools-data-csv-filter

Filter rows of a CSV by a column expression. Supports equality, regex, numeric `<`, `>`, `<=`, `>=`, `!=`, and `--invert`. Column can be specified by header name or zero-based index.

## Usage

```
/cf-tools-data-csv-filter data.csv --col city --eq NYC
/cf-tools-data-csv-filter data.csv --col age --gt 28
/cf-tools-data-csv-filter data.csv --col 0 --regex '^A'
/cf-tools-data-csv-filter data.csv --col city --in NYC,SF --output filtered.csv
/cf-tools-data-csv-filter data.csv --col age --gt 28 --invert
```

Arguments:
1. `csv-path` (required)
2. `--col NAME|INDEX` (required) — header name or 0-based integer
3. One filter (required):
   - `--eq VALUE` — exact string match
   - `--regex PATTERN` — POSIX/Perl regex match
   - `--gt N` / `--lt N` / `--ge N` / `--le N` / `--ne VALUE`
   - `--in V1,V2,V3` — value is one of comma-separated list
   - `--contains SUBSTR` — case-insensitive substring
4. `--invert` (optional) — negate the filter (keep rows that DON'T match)
5. `--output PATH` (optional) — default stdout
6. `--delim ,|;|TAB` (optional, default `,`)

## Why miller (mlr) first

| Tool | Header-aware | Regex | Numeric | Available |
|---|---|---|---|---|
| `mlr --csv filter '$col > 5'` | ✅ | ✅ `=~` | ✅ | brew |
| `awk -F,` | ❌ index only | ✅ | ✅ | always |
| Python `csv.DictReader` | ✅ | ✅ | ✅ | stdlib |
| `grep` | ❌ no header | ✅ | ❌ | always |

mlr is the cleanest: `mlr --csv filter '$city == "NYC"'` reads like SQL. Use Python fallback for index-based access or when mlr isn't installed.

## What You Must Do When Invoked

### Step 1 — Validate

```bash
CSV="$1"; shift
[ -f "$CSV" ] || { echo "ERROR: not found: $CSV"; exit 1; }
# Parse --col, filter op, --invert, --output, --delim
```

### Step 2 — Resolve column

If `--col` is a digit, look up header at that index. If `--col` is a name, ensure it exists in row 1:

```bash
HEADER=$(head -1 "$CSV")
if [[ "$COL" =~ ^[0-9]+$ ]]; then
  COL_NAME=$(echo "$HEADER" | awk -F"$DELIM" -v i=$((COL+1)) '{print $i}')
else
  COL_NAME="$COL"
  echo "$HEADER" | awk -F"$DELIM" -v c="$COL_NAME" '{for(i=1;i<=NF;i++) if($i==c) found=1} END{exit !found}' \
    || { echo "ERROR: column '$COL_NAME' not in header: $HEADER"; exit 1; }
fi
```

### Step 3 — Prefer mlr

```bash
build_mlr_expr() {
  case "$OP" in
    eq)      echo "\$$COL_NAME == \"$VAL\"";;
    ne)      echo "\$$COL_NAME != \"$VAL\"";;
    gt)      echo "\$$COL_NAME > $VAL";;
    lt)      echo "\$$COL_NAME < $VAL";;
    ge)      echo "\$$COL_NAME >= $VAL";;
    le)      echo "\$$COL_NAME <= $VAL";;
    regex)   echo "\$$COL_NAME =~ \"$VAL\"";;
    contains) lower=$(echo "$VAL" | tr 'A-Z' 'a-z'); echo "tolower(\$$COL_NAME) =~ \"$lower\"";;
    in)      IFS=, read -ra arr <<<"$VAL"; e=""; for v in "${arr[@]}"; do e+="\$$COL_NAME == \"$v\" || "; done; echo "${e% || }";;
  esac
}

if command -v mlr >/dev/null 2>&1; then
  EXPR=$(build_mlr_expr)
  $INVERT && FLAG="-x" || FLAG=""
  OUTPUT=$(mlr --csv filter $FLAG "$EXPR" "$CSV")
fi
```

### Step 4 — Python fallback

```bash
OUTPUT=$(python3 - "$CSV" "$COL_NAME" "$OP" "$VAL" "$INVERT" "$DELIM" <<'PY'
import csv, sys, re
path, col, op, val, invert, delim = sys.argv[1:]
invert = invert == "True"
delim = "\t" if delim == "TAB" else delim

def num(x):
    try: return float(x)
    except: return None

def match(row):
    v = row.get(col, "")
    if op == "eq": return v == val
    if op == "ne": return v != val
    if op == "regex": return re.search(val, v) is not None
    if op == "contains": return val.lower() in v.lower()
    if op == "in": return v in val.split(",")
    nv = num(v); nval = num(val)
    if nv is None or nval is None: return False
    return {"gt": nv > nval, "lt": nv < nval, "ge": nv >= nval, "le": nv <= nval}[op]

with open(path, newline="") as f:
    r = csv.DictReader(f, delimiter=delim)
    w = csv.DictWriter(sys.stdout, fieldnames=r.fieldnames, delimiter=delim)
    w.writeheader()
    for row in r:
        keep = match(row)
        if invert: keep = not keep
        if keep: w.writerow(row)
PY
)
```

### Step 5 — Write or print

```bash
if [ -n "$OUT" ]; then echo "$OUTPUT" > "$OUT"; else echo "$OUTPUT"; fi
ROWS=$(echo "$OUTPUT" | tail -n +2 | wc -l | tr -d ' ')
echo "✅ $ROWS rows matched"
```

## Output Contract

```
## CSV filter

**Source:**   data.csv (N total rows)
**Column:**   <name> (resolved from index 2)
**Filter:**   --gt 28 (inverted: false)
**Matched:**  <M> rows
**Output:**   filtered.csv (or stdout)
**Method:**   miller | python-stdlib
```

## Gotchas

- **Numeric comparison on strings**: `--gt 28` on a "29 years" cell fails silently. mlr returns false; Python returns false. Clean data first or use `--regex`.
- **Index 0 vs name "0"**: if a header literally is `"0"`, pass `--col '"0"'` or use the integer 0. Skill treats `--col 0` as index always.
- **Quoted fields with delimiters**: only safe via mlr or csv module. Never split with `cut -d,`.
- **Empty cells in numeric filter**: treated as non-numeric → row excluded. Use `--invert` if you want to keep them.
- **--regex anchors**: pattern is unanchored. Use `^foo$` for full-cell match.
- **Case-insensitive regex**: prefix with `(?i)` (Python) or use `--contains`.

## Cross-Platform Notes

- **macOS / Linux**: install with `brew install miller` or `apt install miller`. Python 3 preinstalled.
- **Windows / WSL**: use WSL; mlr available via Scoop/Choco.
