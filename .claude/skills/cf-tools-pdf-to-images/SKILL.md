---
name: cf-tools-pdf-to-images
description: "Render every PDF page to PNG or JPEG using poppler pdftoppm. Trigger: /cf-tools-pdf-to-images"
trigger: /cf-tools-pdf-to-images
version: 1.0.0
---

# /cf-tools-pdf-to-images

Rasterize each page of a PDF to PNG (or JPEG) at a chosen DPI. Uses poppler's `pdftoppm` — fast, reliable, anti-aliased. Falls back to `magick convert` or `gs` if pdftoppm is missing.

## Usage

```
/cf-tools-pdf-to-images input.pdf                          # 150dpi PNG, ./page-1.png ...
/cf-tools-pdf-to-images input.pdf out-dir/                 # write into out-dir/
/cf-tools-pdf-to-images input.pdf out-dir/ 300             # 300dpi
/cf-tools-pdf-to-images input.pdf out-dir/ 150 jpeg        # JPEG instead of PNG
/cf-tools-pdf-to-images input.pdf out-dir/ 150 png 3-5     # only pages 3..5
```

Arguments:
1. `pdf-path` (required) — source PDF
2. `output-dir` (optional, default `.`) — directory for output images
3. `dpi` (optional, default `150`) — resolution in dots per inch
4. `format` (optional, default `png`) — `png` or `jpeg`
5. `pages` (optional, default `all`) — `F-L` page range

## What You Must Do When Invoked

### Step 1 — Validate

```bash
PDF_PATH="$1"
OUT_DIR="${2:-.}"
DPI="${3:-150}"
FORMAT="${4:-png}"
PAGES="${5:-all}"

[ ! -f "$PDF_PATH" ] && { echo "ERROR: not found: $PDF_PATH" >&2; exit 1; }
mkdir -p "$OUT_DIR"

STEM=$(basename "$PDF_PATH" .pdf)
PREFIX="$OUT_DIR/${STEM}-page"
```

### Step 2 — Render via pdftoppm (primary)

```bash
if command -v pdftoppm >/dev/null 2>&1; then
  CMD=(pdftoppm -r "$DPI")
  case "$FORMAT" in
    png)  CMD+=(-png) ;;
    jpeg|jpg) CMD+=(-jpeg) ;;
    *) echo "ERROR: unknown format '$FORMAT' (use png|jpeg)" >&2; exit 1 ;;
  esac

  if [ "$PAGES" != "all" ]; then
    FIRST="${PAGES%-*}"
    LAST="${PAGES#*-}"
    CMD+=(-f "$FIRST" -l "$LAST")
  fi

  CMD+=("$PDF_PATH" "$PREFIX")
  echo "Running: ${CMD[*]}" >&2
  "${CMD[@]}"
  METHOD="pdftoppm"
fi
```

### Step 3 — Fallback to magick

```bash
if [ ! -f "${PREFIX}-1.${FORMAT}" ] && command -v magick >/dev/null 2>&1; then
  echo "pdftoppm missing — falling back to ImageMagick" >&2
  # magick needs ghostscript installed to read PDFs
  magick -density "$DPI" "$PDF_PATH" "${PREFIX}-%d.${FORMAT}"
  METHOD="magick"
fi
```

### Step 4 — Fallback to ghostscript

```bash
if [ ! -f "${PREFIX}-1.${FORMAT}" ] && command -v gs >/dev/null 2>&1; then
  case "$FORMAT" in
    png)  GS_DEV="png16m" ;;
    jpeg|jpg) GS_DEV="jpeg" ;;
  esac
  gs -dNOPAUSE -dBATCH -dQUIET \
     -sDEVICE="$GS_DEV" \
     -r"$DPI" \
     -sOutputFile="${PREFIX}-%d.${FORMAT}" \
     "$PDF_PATH"
  METHOD="ghostscript"
fi

if [ ! -f "${PREFIX}-1.${FORMAT}" ]; then
  echo "ERROR: no rasterizer available. Run: brew install poppler" >&2
  exit 1
fi
```

### Step 5 — Report

```bash
PRODUCED=$(ls -1 "${PREFIX}"-*."${FORMAT}" 2>/dev/null | wc -l | tr -d ' ')
SAMPLE=$(ls -1 "${PREFIX}"-*."${FORMAT}" 2>/dev/null | head -1)
if [ -n "$SAMPLE" ]; then
  if command -v sips >/dev/null 2>&1; then
    DIMS=$(sips -g pixelWidth -g pixelHeight "$SAMPLE" 2>/dev/null | \
      awk '/pixel/ {print $2}' | paste -sd 'x' -)
  fi
  echo "✅ Rendered $PRODUCED pages at ${DPI}dpi → $OUT_DIR" >&2
  echo "   Sample: $SAMPLE ($DIMS)" >&2
  echo "   Method: $METHOD" >&2
fi
```

## Output Contract

```
## PDF → image render

**Source:**  <pdf-path>
**Output:**  <dir>/<stem>-page-1.<ext> ... <stem>-page-N.<ext>
**Pages:**   <produced> (<F-L> if range)
**DPI:**     <N>
**Format:**  png | jpeg
**Method:**  pdftoppm | magick | ghostscript
```

## Gotchas

- **`pdftoppm` numbers from 1 with default padding** — for multi-digit page counts, pass `-l` end and use `-r` to ensure consistent dimensions across pages.
- **Page numbers have no zero-padding by default** — sort with `ls -1v` or `sort -V`. Add `-l N` to set the total digit width (e.g. `-l 100` produces `page-001.png`).
- **`magick` requires ghostscript** under the hood to read PDFs. If ghostscript is missing, magick errors with "no decode delegate for PDF".
- **High DPI (>300) blows up file size** — a typical letter page at 600dpi PNG is 8–20 MB. Default 150 is plenty for OCR or web preview.
- **Anti-aliasing**: pdftoppm enables AA by default (`-aa yes -aaVector yes`). Disable with `-aa no` only for pixel-art or low-DPI bitmap output.
- **Color space**: pdftoppm output is sRGB. For CMYK preservation use `gs -sDEVICE=tiffsep` then convert.
- **Transparency in PNG**: pass `-transp` to pdftoppm to keep the PDF page transparency (otherwise default is white background).
- **Encrypted PDFs** fail; decrypt first with `qpdf --decrypt --password=PWD in.pdf out.pdf`.

## Cross-Platform Notes

- **macOS**: `brew install poppler` (pdftoppm). `brew install ghostscript imagemagick` for fallbacks.
- **Linux**: `apt install poppler-utils ghostscript imagemagick`.
- **Windows**: poppler windows binaries on PATH, or use WSL.
