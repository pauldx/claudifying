---
name: cf-tools-pdf-split
description: "Split a PDF into per-page files or extract a page range. Trigger: /cf-tools-pdf-split"
trigger: /cf-tools-pdf-split
version: 1.0.0
---

# /cf-tools-pdf-split

Two modes:
1. **Burst** — split every page into its own PDF (`pdfseparate`).
2. **Range** — extract a contiguous page range into one new PDF (`qpdf` or `pdfseparate + pdfunite`).

## Usage

```
/cf-tools-pdf-split input.pdf                              # burst into ./page-1.pdf, page-2.pdf, ...
/cf-tools-pdf-split input.pdf out-dir/                     # burst into out-dir/page-%d.pdf
/cf-tools-pdf-split input.pdf out.pdf --pages 5-10         # extract pages 5..10 into out.pdf
/cf-tools-pdf-split input.pdf out.pdf --pages 3            # extract single page 3
```

Arguments:
1. `pdf-path` (required) — source PDF
2. `output` (optional) — output directory (burst) or output PDF path (range)
3. `--pages F-L` or `--pages N` (optional) — switches to range mode

## What You Must Do When Invoked

### Step 1 — Validate and parse args

```bash
PDF_PATH="$1"
OUTPUT="${2:-.}"
MODE="burst"
PAGE_RANGE=""

shift 2 2>/dev/null || true
while [ $# -gt 0 ]; do
  case "$1" in
    --pages) PAGE_RANGE="$2"; MODE="range"; shift 2 ;;
    *) shift ;;
  esac
done

if [ ! -f "$PDF_PATH" ]; then
  echo "ERROR: PDF not found: $PDF_PATH" >&2
  exit 1
fi

TOTAL=$(pdfinfo "$PDF_PATH" 2>/dev/null | awk '/^Pages:/ {print $2}')
echo "Source: $PDF_PATH ($TOTAL pages)" >&2
```

### Step 2a — Burst mode (one file per page)

```bash
if [ "$MODE" = "burst" ]; then
  if ! command -v pdfseparate >/dev/null 2>&1; then
    echo "ERROR: pdfseparate not installed. Run: brew install poppler" >&2
    exit 1
  fi

  # If $OUTPUT is a directory, write inside it. Otherwise treat as pattern.
  if [ -d "$OUTPUT" ] || [[ "$OUTPUT" == */ ]]; then
    mkdir -p "$OUTPUT"
    PATTERN="${OUTPUT%/}/page-%d.pdf"
  else
    PATTERN="$OUTPUT"
  fi

  echo "Bursting into pattern: $PATTERN" >&2
  pdfseparate "$PDF_PATH" "$PATTERN"

  # Count produced files
  PRODUCED=$(ls -1 "$(dirname "$PATTERN")"/page-*.pdf 2>/dev/null | wc -l | tr -d ' ')
  echo "✅ Burst $TOTAL pages → $PRODUCED files in $(dirname "$PATTERN")" >&2
  exit 0
fi
```

### Step 2b — Range mode (single output PDF)

```bash
if [ "$MODE" = "range" ]; then
  # Normalize "5" → "5-5"
  if [[ "$PAGE_RANGE" != *-* ]]; then
    PAGE_RANGE="${PAGE_RANGE}-${PAGE_RANGE}"
  fi
  FIRST="${PAGE_RANGE%-*}"
  LAST="${PAGE_RANGE#*-}"

  if [ "$FIRST" -lt 1 ] || [ "$LAST" -gt "$TOTAL" ] || [ "$FIRST" -gt "$LAST" ]; then
    echo "ERROR: invalid range $PAGE_RANGE (PDF has $TOTAL pages)" >&2
    exit 1
  fi

  # Prefer qpdf for single-shot range extraction (no temp files)
  if command -v qpdf >/dev/null 2>&1; then
    echo "Extracting pages $FIRST-$LAST via qpdf..." >&2
    qpdf "$PDF_PATH" --pages . "$FIRST-$LAST" -- "$OUTPUT"
    METHOD="qpdf"
  else
    # Fallback: pdfseparate range + pdfunite
    echo "qpdf missing — falling back to pdfseparate + pdfunite..." >&2
    TMP=$(mktemp -d)
    pdfseparate -f "$FIRST" -l "$LAST" "$PDF_PATH" "$TMP/p-%d.pdf"
    # shellcheck disable=SC2046
    pdfunite $(ls "$TMP"/p-*.pdf | sort -V) "$OUTPUT"
    rm -rf "$TMP"
    METHOD="pdfseparate+pdfunite"
  fi

  ACTUAL=$(pdfinfo "$OUTPUT" 2>/dev/null | awk '/^Pages:/ {print $2}')
  EXPECTED=$((LAST - FIRST + 1))
  echo "✅ Extracted $ACTUAL pages → $OUTPUT (expected $EXPECTED) via $METHOD" >&2
fi
```

## Output Contract

Burst:
```
## PDF burst

**Source:**  <pdf-path>
**Output:**  <out-dir>/page-1.pdf … page-N.pdf
**Pages:**   <N>
```

Range:
```
## PDF range extract

**Source:**  <pdf-path> (<total> pages)
**Range:**   <F>-<L>
**Output:**  <out.pdf> (<actual> pages)
**Method:**  qpdf | pdfseparate+pdfunite
```

## Gotchas

- **`pdfseparate` output pattern must contain `%d`** literally — it substitutes the 1-indexed page number. `page-%d.pdf` becomes `page-1.pdf`, `page-2.pdf`, etc.
- **No leading zeros by default** — sort with `ls -1v` or `sort -V` if you need natural ordering of >10 pages.
- **Page numbers in qpdf `--pages` are 1-indexed and inclusive** — `1-3` extracts 3 pages.
- **qpdf `--pages . FIRST-LAST --`** — the standalone `.` means "the source file itself"; the trailing `--` ends the pages spec.
- **Encrypted PDFs**: decrypt with `qpdf --decrypt --password=PWD in.pdf out.pdf` first.
- **Output directory must exist** for burst mode — the script `mkdir -p`s it; without that you'd get "No such file" errors.
- **Bookmarks/outline** are dropped in pdfseparate output (each page is a fresh PDF). Use qpdf if you need them carried.

## Cross-Platform Notes

- **macOS**: `brew install poppler qpdf`.
- **Linux**: `apt install poppler-utils qpdf`.
- **Windows**: poppler windows binaries + qpdf release zip, or WSL.
