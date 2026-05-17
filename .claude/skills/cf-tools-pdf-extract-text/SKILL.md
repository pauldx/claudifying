---
name: cf-tools-pdf-extract-text
description: "Extract plain text from a PDF using poppler pdftotext. Trigger: /cf-tools-pdf-extract-text"
trigger: /cf-tools-pdf-extract-text
version: 1.0.0
---

# /cf-tools-pdf-extract-text

Extract searchable text from a PDF and emit it to stdout or a `.txt` file. Uses poppler's `pdftotext` — fast, accurate, ships in every poppler install. Preserves reading order, optionally preserves layout columns/tables.

## Usage

```
/cf-tools-pdf-extract-text /path/to/input.pdf
/cf-tools-pdf-extract-text /path/to/input.pdf out.txt
/cf-tools-pdf-extract-text /path/to/input.pdf out.txt --layout       # preserve columns
/cf-tools-pdf-extract-text /path/to/input.pdf out.txt --pages 3-5    # only pages 3..5
```

Arguments:
1. `pdf-path` (required) — absolute or relative path to source PDF
2. `output` (optional, default `-` = stdout) — `.txt` output path or `-` for stdout
3. `--layout` (optional flag) — preserve physical layout (tables, multi-column)
4. `--pages F-L` (optional) — restrict to first..last page range (inclusive)

## Why pdftotext

| Tool | Speed | Layout fidelity | Install |
|---|---|---|---|
| `pdftotext` (poppler) | ✅ fast | ✅ with `-layout` | `brew install poppler` |
| `pdfplumber` (Python) | ⚠️ slow on big PDFs | ✅✅ table-aware | `pip install pdfplumber` |
| `pypdf` | ✅ fast | ⚠️ flow-only | `pip install pypdf` |
| `gs -sDEVICE=txtwrite` | ⚠️ slow | ⚠️ basic | `brew install ghostscript` |

`pdftotext` wins for raw extraction. Reach for `pdfplumber` only when you need cell-by-cell table data.

## What You Must Do When Invoked

### Step 1 — Validate input

```bash
PDF_PATH="<arg1>"
OUTPUT="${2:--}"     # default stdout
LAYOUT_FLAG=""
PAGE_RANGE=""

if [ ! -f "$PDF_PATH" ]; then
  echo "ERROR: PDF not found: $PDF_PATH" >&2
  exit 1
fi

# Parse optional flags from remaining args
for arg in "$@"; do
  case "$arg" in
    --layout) LAYOUT_FLAG="-layout" ;;
    --pages) NEXT_IS_PAGES=1 ;;
    *) if [ "$NEXT_IS_PAGES" = "1" ]; then PAGE_RANGE="$arg"; NEXT_IS_PAGES=0; fi ;;
  esac
done
```

### Step 2 — Verify the tool exists

```bash
if ! command -v pdftotext >/dev/null 2>&1; then
  echo "ERROR: pdftotext not installed. Run: brew install poppler" >&2
  exit 1
fi
```

### Step 3 — Build the command

```bash
CMD=(pdftotext)
[ -n "$LAYOUT_FLAG" ] && CMD+=("$LAYOUT_FLAG")

if [ -n "$PAGE_RANGE" ]; then
  FIRST="${PAGE_RANGE%-*}"
  LAST="${PAGE_RANGE#*-}"
  CMD+=(-f "$FIRST" -l "$LAST")
fi

CMD+=("$PDF_PATH" "$OUTPUT")

echo "Running: ${CMD[*]}" >&2
"${CMD[@]}"
```

### Step 4 — Report

If writing to a file, print the byte count and a 5-line preview:

```bash
if [ "$OUTPUT" != "-" ] && [ -f "$OUTPUT" ]; then
  BYTES=$(wc -c < "$OUTPUT" | tr -d ' ')
  echo "✅ Extracted $BYTES bytes → $OUTPUT" >&2
  echo "--- preview ---" >&2
  head -n 5 "$OUTPUT" >&2
fi
```

## Output Contract

```
## PDF text extraction

**Source:**  <pdf-path>
**Output:**  <txt-path or stdout>
**Pages:**   all | F-L
**Layout:**  flow | preserved (-layout)
**Size:**    <bytes>
**Preview:** first 5 lines of extracted text
```

## Gotchas

- **Scanned PDFs (image-only)** produce empty output. Run OCR first: `ocrmypdf input.pdf ocr.pdf` (`brew install ocrmypdf`) then re-extract.
- **`-layout` adds whitespace padding** to preserve column alignment. Good for tables, bad for prose downstream parsing.
- **Ligatures like `ﬁ` / `ﬂ`** come through as Unicode. Pipe through `iconv -f utf-8 -t ascii//translit` if downstream needs ASCII.
- **Page ranges are 1-indexed and inclusive**. `--pages 1-1` gets only page 1.
- **CRLF line endings** appear on Windows-generated PDFs. Run `tr -d '\r'` if you need LF only.
- **Encrypted PDFs** fail with `Command Line Error: Incorrect password`. Decrypt first: `qpdf --decrypt --password=PWD in.pdf out.pdf`.

## Cross-Platform Notes

- **macOS**: `brew install poppler` (provides pdftotext, pdfinfo, pdftoppm, pdfunite, pdfseparate).
- **Linux**: `apt install poppler-utils` (Debian/Ubuntu) or `dnf install poppler-utils` (Fedora).
- **Windows**: download poppler binaries from `https://github.com/oschwartz10612/poppler-windows` and add `bin/` to PATH, or use WSL.
