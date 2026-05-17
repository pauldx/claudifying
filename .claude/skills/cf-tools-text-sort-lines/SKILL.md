---
name: cf-tools-text-sort-lines
description: "Smart line sort — numeric, reverse, by column, random, case-insensitive. Trigger: /cf-tools-text-sort-lines"
trigger: /cf-tools-text-sort-lines
version: 1.0.0
---

# /cf-tools-text-sort-lines

Sort lines from a file or stdin with flag-driven modes. Wraps `sort` with sane defaults and handles BSD/GNU differences.

## Usage

```
/cf-tools-text-sort-lines input.txt
/cf-tools-text-sort-lines input.txt --reverse
/cf-tools-text-sort-lines input.txt --numeric
/cf-tools-text-sort-lines data.csv --by-column 2 --sep ,
/cf-tools-text-sort-lines names.txt --case-insensitive
/cf-tools-text-sort-lines deck.txt --random
cat data.tsv | /cf-tools-text-sort-lines --by-column 3 --sep $'\t' --numeric
```

Arguments:
1. `input` (optional) — file path; stdin if omitted
2. `--reverse` / `-r` (optional) — descending order
3. `--numeric` / `-n` (optional) — numeric sort (`10` after `2`, not before)
4. `--by-column N` (optional) — sort by 1-indexed field N
5. `--sep CHAR` (optional, default whitespace) — field separator
6. `--case-insensitive` / `-f` (optional) — fold case
7. `--random` (optional) — randomize order
8. `--unique` / `-u` (optional) — collapse duplicates after sort
9. `--output PATH` (optional) — write to file

## Self-Contained Snippet

```bash
INPUT="${1:-/dev/stdin}"
# Numeric reverse sort, dedupe:
sort -nru "$INPUT"
# Random shuffle (BSD: sort -R, GNU: shuf):
sort -R "$INPUT" 2>/dev/null || shuf "$INPUT"
# Sort by 2nd column (comma-separated):
sort -t, -k2,2 "$INPUT"
```

## What You Must Do When Invoked

### Step 1 — Parse flags

```bash
REVERSE=""; NUMERIC=""; BY=0; SEP=""; CI=""; RANDOM_=0; UNIQUE=""; OUT=""; IN=""
while [ $# -gt 0 ]; do
  case "$1" in
    -r|--reverse) REVERSE="-r"; shift;;
    -n|--numeric) NUMERIC="-n"; shift;;
    --by-column) BY="$2"; shift 2;;
    --sep) SEP="$2"; shift 2;;
    -f|--case-insensitive) CI="-f"; shift;;
    --random) RANDOM_=1; shift;;
    -u|--unique) UNIQUE="-u"; shift;;
    --output) OUT="$2"; shift 2;;
    *) IN="$1"; shift;;
  esac
done
SRC="${IN:-/dev/stdin}"
```

### Step 2 — Random mode shortcut

```bash
if [ "$RANDOM_" -eq 1 ]; then
  if command -v shuf >/dev/null 2>&1; then
    shuf "$SRC"
  else
    sort -R "$SRC"   # BSD/macOS sort supports -R
  fi | { [ -n "$OUT" ] && tee "$OUT" >/dev/null || cat; }
  exit 0
fi
```

### Step 3 — Build sort command

```bash
ARGS="$REVERSE $NUMERIC $CI $UNIQUE"
if [ "$BY" -gt 0 ]; then
  SEP_CHAR="${SEP:- }"
  sort -t"$SEP_CHAR" -k"$BY,$BY" $ARGS "$SRC"
else
  sort $ARGS "$SRC"
fi | { [ -n "$OUT" ] && tee "$OUT" >/dev/null || cat; }
```

### Step 4 — Report

```bash
LINES=$(wc -l < "$SRC" 2>/dev/null || echo "?")
echo "Sorted $LINES lines"
```

## Output Contract

```
## Sort

Source:        <file|stdin>
Order:         ascending | descending | random
Key:           whole-line | column <N>
Mode:          lexicographic | numeric
Case:          sensitive | insensitive
Dedupe:        yes | no
Lines in/out:  <N> / <M>
Output:        <file|stdout>
```

## Gotchas

- **Numeric vs lex**: lexicographic sort puts `"10"` before `"2"`. Always use `-n` for numeric data. `-g` (general numeric) handles scientific notation but is slower.
- **`-k 2` vs `-k 2,2`**: `-k 2` sorts by **field 2 to end of line**, which is rarely what you want when secondary fields matter. `-k 2,2` sorts strictly by field 2.
- **Default separator**: bare `sort` splits on whitespace runs. For CSVs use `-t,`. For TSVs use `-t$'\t'` (bash) or `-t"$(printf '\t')"`.
- **Stable sort**: GNU `sort` has `--stable`; BSD `sort` is stable for equal keys by default. Verify if you depend on order preservation among equal keys.
- **`-R` and `shuf` reproducibility**: neither is seeded by default. GNU `shuf --random-source=...` lets you fix a seed. BSD `sort -R` cannot.
- **Locale-sensitive sort**: `LC_ALL=C sort` for byte-order ASCII sort. Default locale may sort `a < B < c` (case-folded). Set explicitly when scripts need to be reproducible.

## Cross-Platform Notes

| Feature | macOS (BSD) | Linux (GNU) |
|---------|-------------|-------------|
| Random | `sort -R` | `sort -R` or `shuf` |
| Numeric | `-n` / `-g` | `-n` / `-g` / `-h` (human-readable: `1K`, `2M`) |
| Stable | implicit | `--stable` flag |
| Parallel | not supported | `--parallel=N` |
| Unicode | locale-dependent | locale-dependent |

Prefer `LC_ALL=C sort` for portable, reproducible byte-level sorts in scripts.
