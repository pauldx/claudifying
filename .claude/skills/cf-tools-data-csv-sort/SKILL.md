---
name: cf-tools-data-csv-sort
description: "Sort CSV rows by one or more columns, numeric or lexical, ascending or reverse. Trigger: /cf-tools-data-csv-sort"
trigger: /cf-tools-data-csv-sort
version: 1.0.0
---

# /cf-tools-data-csv-sort

Sort a CSV by one or more columns. Defaults to lexical ascending. Header row is preserved. Column can be specified by name or 0-based index. Multiple keys supported (`--col a,b`) with per-key flags.

## Usage

```
/cf-tools-data-csv-sort data.csv --col age --numeric
/cf-tools-data-csv-sort data.csv --col name
/cf-tools-data-csv-sort data.csv --col age --numeric --reverse
/cf-tools-data-csv-sort data.csv --col city,age --numeric --output sorted.csv
/cf-tools-data-csv-sort data.csv --col 1 --numeric
```

Arguments:
1. `csv-path` (required)
2. `--col NAME|INDEX[,NAME|INDEX...]` (required) — primary then secondary keys
3. `--numeric` (optional) — numeric sort (default lexical)
4. `--reverse` (optional) — descending
5. `--output PATH` (optional) — default stdout
6. `--delim ,|;|TAB` (optional, default `,`)
7. `--unique` (optional) — drop duplicate rows (post-sort)

## Why miller (mlr) first

| Tool | Header preserved | Multi-key | Numeric | Available |
|---|---|---|---|---|
| `mlr --csv sort` | ✅ | ✅ `-f a -nr b` | ✅ | brew |
| `(head -1; tail -n+2 \| sort)` | ✅ (manual) | ✅ | ✅ `-n` | always |
| Python `csv` + `sorted` | ✅ | ✅ | ✅ | stdlib |

mlr keeps the header in place automatically. The head/tail trick is fine for one key but fragile with multi-key + delimiter mixing.

## What You Must Do When Invoked

### Step 1 — Validate

```bash
CSV="$1"; shift
[ -f "$CSV" ] || { echo "ERROR: not found: $CSV"; exit 1; }
# Parse: COLS (comma list), NUMERIC, REVERSE, OUT, DELIM, UNIQUE
```

### Step 2 — Resolve column names

```bash
HEADER=$(head -1 "$CSV")
IFS=, read -ra RAW_COLS <<<"$COLS"
RESOLVED=()
for c in "${RAW_COLS[@]}"; do
  if [[ "$c" =~ ^[0-9]+$ ]]; then
    name=$(echo "$HEADER" | awk -F"$DELIM" -v i=$((c+1)) '{print $i}')
  else
    name="$c"
  fi
  RESOLVED+=("$name")
done
```

### Step 3 — Prefer mlr

```bash
# mlr flag mapping:
#   lexical asc:  -f col
#   lexical desc: -r col
#   numeric asc:  -nf col
#   numeric desc: -nr col
if command -v mlr >/dev/null 2>&1; then
  FLAGS=""
  for c in "${RESOLVED[@]}"; do
    if $NUMERIC && $REVERSE; then FLAGS+=" -nr $c"
    elif $NUMERIC;            then FLAGS+=" -nf $c"
    elif $REVERSE;            then FLAGS+=" -r $c"
    else                            FLAGS+=" -f $c"
    fi
  done
  PIPE="sort$FLAGS"
  $UNIQUE && PIPE+=" then uniq -a"
  OUTPUT=$(mlr --csv $PIPE "$CSV")
fi
```

### Step 4 — Python fallback

```bash
OUTPUT=$(python3 - "$CSV" "$(IFS=,; echo "${RESOLVED[*]}")" "$NUMERIC" "$REVERSE" "$UNIQUE" "$DELIM" <<'PY'
import csv, sys, io
path, cols, numeric, reverse, uniq, delim = sys.argv[1:]
cols = cols.split(","); numeric = numeric == "True"; reverse = reverse == "True"; uniq = uniq == "True"
delim = "\t" if delim == "TAB" else delim

def keyfn(row):
    out = []
    for c in cols:
        v = row.get(c, "")
        if numeric:
            try: out.append(float(v))
            except: out.append(float("-inf") if not reverse else float("inf"))
        else:
            out.append(v)
    return tuple(out)

with open(path, newline="") as f:
    r = csv.DictReader(f, delimiter=delim)
    rows = list(r)
    rows.sort(key=keyfn, reverse=reverse)
    if uniq:
        seen, dedup = set(), []
        for row in rows:
            k = tuple(row.items())
            if k not in seen: seen.add(k); dedup.append(row)
        rows = dedup
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=r.fieldnames, delimiter=delim)
    w.writeheader()
    for row in rows: w.writerow(row)
    sys.stdout.write(buf.getvalue())
PY
)
```

### Step 5 — Write or print

```bash
if [ -n "$OUT" ]; then printf '%s' "$OUTPUT" > "$OUT"; else printf '%s' "$OUTPUT"; fi
ROWS=$(echo "$OUTPUT" | tail -n +2 | wc -l | tr -d ' ')
echo "✅ Sorted $ROWS rows by [${RESOLVED[*]}] $($NUMERIC && echo 'numeric') $($REVERSE && echo 'reverse')"
```

## Output Contract

```
## CSV sort

**Source:**   data.csv
**Keys:**     [age, name] (resolved from indices/names)
**Mode:**     numeric | lexical, ascending | reverse
**Rows:**     <N>
**Output:**   sorted.csv (or stdout)
**Method:**   miller | python-stdlib
```

## Gotchas

- **Mixed numeric/string in numeric mode**: non-numeric values fall to `-inf` (ascending) or `+inf` (reverse). Clean first or use lexical.
- **Stability**: both mlr and Python's `sorted` are stable — equal keys preserve original order.
- **Locale-dependent lexical**: Python uses Unicode codepoint order; mlr uses byte order. "Z" < "a" in both. Set `LC_ALL=C` for predictable results.
- **Index vs name "0"**: numeric-looking string `--col 0` is treated as index. Use name form if your header literally is `"0"`.
- **Multi-key reverse**: `--reverse` applies to ALL keys. mlr supports per-key direction with explicit `-f/-r` pairs — not exposed here.
- **--unique on a single column**: this skill dedupes by the whole row, not just sort keys. Pre-cut columns if you want key-only uniq.

## Cross-Platform Notes

- **macOS / Linux**: `brew install miller` / `apt install miller`. Set `LC_ALL=C` in scripts for byte-order sort.
- **Windows / WSL**: WSL recommended. Excel may re-sort on open — verify with `head` after writing.
