---
name: cf-tools-pdf-info
description: "Report PDF metadata: page count, size, fonts, encryption, producer. Trigger: /cf-tools-pdf-info"
trigger: /cf-tools-pdf-info
version: 1.0.0
---

# /cf-tools-pdf-info

Print structured metadata about a PDF: title, author, page count, page size, fonts, encryption, tagging, producer, and creation/modification dates. Uses `pdfinfo` (poppler) plus `pdffonts` for the font table.

## Usage

```
/cf-tools-pdf-info input.pdf
/cf-tools-pdf-info input.pdf --json          # emit as JSON
/cf-tools-pdf-info input.pdf --fonts         # include font table
```

Arguments:
1. `pdf-path` (required) — source PDF
2. `--json` (optional flag) — emit machine-readable JSON
3. `--fonts` (optional flag) — append the font table from `pdffonts`

## What You Must Do When Invoked

### Step 1 — Validate

```bash
PDF_PATH="$1"
shift
JSON_MODE=0
FONTS_MODE=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE=1 ;;
    --fonts) FONTS_MODE=1 ;;
  esac
done

[ ! -f "$PDF_PATH" ] && { echo "ERROR: not found: $PDF_PATH" >&2; exit 1; }

if ! command -v pdfinfo >/dev/null 2>&1; then
  echo "ERROR: pdfinfo not installed. Run: brew install poppler" >&2
  exit 1
fi
```

### Step 2 — Capture pdfinfo output

```bash
INFO=$(pdfinfo "$PDF_PATH" 2>/dev/null)

# Extract key fields
TITLE=$(echo "$INFO" | awk -F': +' '/^Title:/ {print $2}')
AUTHOR=$(echo "$INFO" | awk -F': +' '/^Author:/ {print $2}')
PRODUCER=$(echo "$INFO" | awk -F': +' '/^Producer:/ {print $2}')
CREATOR=$(echo "$INFO" | awk -F': +' '/^Creator:/ {print $2}')
CREATED=$(echo "$INFO" | awk -F': +' '/^CreationDate:/ {print $2}')
MODIFIED=$(echo "$INFO" | awk -F': +' '/^ModDate:/ {print $2}')
PAGES=$(echo "$INFO" | awk -F': +' '/^Pages:/ {print $2}')
PAGESIZE=$(echo "$INFO" | awk -F': +' '/^Page size:/ {print $2}')
ENCRYPTED=$(echo "$INFO" | awk -F': +' '/^Encrypted:/ {print $2}')
TAGGED=$(echo "$INFO" | awk -F': +' '/^Tagged:/ {print $2}')
PDF_VERSION=$(echo "$INFO" | awk -F': +' '/^PDF version:/ {print $2}')
FILESIZE=$(echo "$INFO" | awk -F': +' '/^File size:/ {print $2}')
```

### Step 3 — Emit human or JSON

```bash
if [ "$JSON_MODE" = "1" ]; then
  python3 - <<PY
import json
print(json.dumps({
  "path": "$PDF_PATH",
  "title": """$TITLE""".strip() or None,
  "author": """$AUTHOR""".strip() or None,
  "producer": """$PRODUCER""".strip() or None,
  "creator": """$CREATOR""".strip() or None,
  "created": """$CREATED""".strip() or None,
  "modified": """$MODIFIED""".strip() or None,
  "pages": int("""$PAGES""".strip() or 0),
  "page_size": """$PAGESIZE""".strip(),
  "encrypted": """$ENCRYPTED""".strip().lower().startswith("yes"),
  "tagged": """$TAGGED""".strip().lower() == "yes",
  "pdf_version": """$PDF_VERSION""".strip(),
  "file_size": """$FILESIZE""".strip(),
}, indent=2))
PY
else
  cat <<EOF
## PDF info

**Path:**       $PDF_PATH
**Title:**      ${TITLE:-—}
**Author:**     ${AUTHOR:-—}
**Producer:**   ${PRODUCER:-—}
**Creator:**    ${CREATOR:-—}
**Created:**    ${CREATED:-—}
**Modified:**   ${MODIFIED:-—}
**Pages:**      $PAGES
**Page size:**  $PAGESIZE
**PDF version:** $PDF_VERSION
**File size:**  $FILESIZE
**Encrypted:**  $ENCRYPTED
**Tagged:**     $TAGGED
EOF
fi
```

### Step 4 — Optional font table

```bash
if [ "$FONTS_MODE" = "1" ] && command -v pdffonts >/dev/null 2>&1; then
  echo ""
  echo "## Embedded fonts"
  echo ""
  pdffonts "$PDF_PATH"
fi
```

## Output Contract

Human mode:
```
## PDF info

**Path:**       <pdf-path>
**Title:**      <title or —>
**Author:**     <author or —>
**Producer:**   <producer>
**Creator:**    <creator>
**Created:**    <date>
**Modified:**   <date>
**Pages:**      <N>
**Page size:**  <W x H pts (named)>
**PDF version:** <e.g. 1.7>
**File size:**  <bytes>
**Encrypted:**  yes | no
**Tagged:**     yes | no
```

JSON mode emits the same keys as a single JSON object.

## Gotchas

- **`pdfinfo` returns non-zero on encrypted PDFs** without a password. Detect with `pdfinfo file.pdf 2>&1 | grep "Incorrect password"` and prompt for one (`pdfinfo -upw PWD file.pdf`).
- **Page size shows in points** (1 pt = 1/72 inch). 612x792 = US Letter, 595x842 = A4. The trailing `(letter)` / `(A4)` name is added by poppler when recognized.
- **Multi-page PDFs with varied page sizes** — `pdfinfo` only shows the first page's size. Use `pdfinfo -f 1 -l N` to enumerate or parse the `-box` output.
- **PDF date format** is `D:YYYYMMDDHHmmSS±HH'MM'`. poppler renders it human-readable already; for round-tripping use `xpdf-utils` or pikepdf.
- **`Tagged: yes`** indicates structural tags exist but does not guarantee correct accessibility. Run an accessibility checker (e.g. PAC 2024) for compliance.
- **Producer vs Creator** — Creator is the app that authored the source (Word, InDesign); Producer is the library that wrote the PDF bytes (PDFKit, Skia/PDF).
- **`pdffonts` lists every font reference** including those that are subset-embedded; "emb yes / sub yes" means subset-embedded (a partial font), "emb no" means relying on system fonts.

## Cross-Platform Notes

- **macOS**: `brew install poppler` (includes pdfinfo and pdffonts).
- **Linux**: `apt install poppler-utils`.
- **Windows**: poppler windows binaries on PATH, or WSL.
