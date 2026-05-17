---
name: cf-tools-text-dedupe
description: "Remove duplicate lines from a file, preserve order or sort, dedupe by column. Trigger: /cf-tools-text-dedupe"
trigger: /cf-tools-text-dedupe
version: 1.0.0
---

# /cf-tools-text-dedupe

Strip duplicate lines from a text file. Two modes: preserve original order (default, via `awk`) or sort then dedupe (via `sort -u`). Optional column-based dedupe for CSV/TSV.

## Usage

```
/cf-tools-text-dedupe input.txt                    # preserve order
/cf-tools-text-dedupe input.txt --sort             # sort + dedupe
/cf-tools-text-dedupe input.csv --by 2 --sep ,     # dedupe by 2nd column
/cf-tools-text-dedupe input.txt --output clean.txt # write to file (default: stdout)
```

Arguments:
1. `input` (required) — source file
2. `--sort` (optional) — sort output instead of preserving order
3. `--by N` (optional) — dedupe based on field N (1-indexed)
4. `--sep CHAR` (optional, default whitespace) — field separator for `--by`
5. `--output PATH` (optional) — write result to file instead of stdout
6. `--case-insensitive` (optional) — match keys without case sensitivity

## Self-Contained Snippet

```bash
INPUT="$1"
[ -f "$INPUT" ] || { echo "ERROR: file not found"; exit 1; }
# Preserve original order — keep first occurrence
awk '!seen[$0]++' "$INPUT"
# Or sort + dedupe:
# sort -u "$INPUT"
```

## What You Must Do When Invoked

### Step 1 — Validate

```bash
INPUT="$1"
[ -f "$INPUT" ] || { echo "ERROR: file not found: $INPUT"; exit 1; }
```

### Step 2 — Parse flags

```bash
SORT=0; BY=0; SEP=""; OUT=""; CI=0
shift
while [ $# -gt 0 ]; do
  case "$1" in
    --sort) SORT=1; shift;;
    --by) BY="$2"; shift 2;;
    --sep) SEP="$2"; shift 2;;
    --output) OUT="$2"; shift 2;;
    --case-insensitive) CI=1; shift;;
    *) shift;;
  esac
done
```

### Step 3 — Dispatch dedupe mode

```bash
KEY_EXPR='$0'
[ "$BY" -gt 0 ] && KEY_EXPR="\$$BY"
[ "$CI" -eq 1 ] && KEY_EXPR="tolower($KEY_EXPR)"

AWK_PROG="!seen[$KEY_EXPR]++"
AWK_ARGS=""
[ -n "$SEP" ] && AWK_ARGS="-F$SEP"

if [ "$SORT" -eq 1 ]; then
  if [ "$BY" -gt 0 ]; then
    sort -u -t"${SEP:- }" -k"$BY,$BY" "$INPUT"
  else
    [ "$CI" -eq 1 ] && sort -fu "$INPUT" || sort -u "$INPUT"
  fi
else
  awk $AWK_ARGS "$AWK_PROG" "$INPUT"
fi | { [ -n "$OUT" ] && tee "$OUT" >/dev/null || cat; }
```

### Step 4 — Report stats

```bash
BEFORE=$(wc -l < "$INPUT")
AFTER=$(if [ -n "$OUT" ]; then wc -l < "$OUT"; else awk '!seen[$0]++' "$INPUT" | wc -l; fi)
echo "Before: $BEFORE lines  After: $AFTER lines  Removed: $((BEFORE - AFTER))"
```

## Output Contract

```
## Dedupe: <input>

Mode:        preserve-order | sorted
Dedupe key:  whole-line | column <N>
Before:      <N> lines
After:       <M> lines
Removed:     <N-M> duplicates
Output:      <path or stdout>
```

## Gotchas

- **`uniq` alone won't work**: classic `uniq` only removes *adjacent* duplicates. Must `sort | uniq` or use `awk '!seen[$0]++'`.
- **Order vs sort**: `awk '!seen[$0]++'` keeps first occurrence in original order; `sort -u` reorders alphabetically. Pick deliberately.
- **Memory**: `awk` builds a hash of every unique line. For 10M+ line files use `sort -u` (uses external merge sort).
- **Column dedupe gotcha**: With `--by 2`, two rows where col 2 matches but other cols differ — only the first is kept. Document this clearly to the caller.
- **Whitespace-only differences**: lines with trailing spaces look identical but aren't. Run through `sed 's/[[:space:]]*$//'` first if needed.

## Cross-Platform Notes

- **macOS / BSD awk**: `!seen[$0]++` works identically to GNU awk.
- **GNU sort `-fu`**: case-insensitive unique. macOS BSD sort supports this too.
- **`sort -k`**: both BSD and GNU accept `-k N,N` for column-restricted sort.
- **`tee`**: portable; safer than redirecting through subshells.
