---
name: cf-tools-pdf-watermark
description: "Stamp text or image watermark on every page of a PDF. Trigger: /cf-tools-pdf-watermark"
trigger: /cf-tools-pdf-watermark
version: 1.0.0
---

# /cf-tools-pdf-watermark

Stamp a watermark — text or a single-page PDF overlay — onto every page of an input PDF. Two backends in priority order:

1. `pdftk` (`pdftk-java`) — `stamp` operation with a watermark PDF
2. `gs` (ghostscript) — composites text via PostScript
3. `qpdf` + `pikepdf` (Python) — overlay form-XObject

## Usage

```
/cf-tools-pdf-watermark input.pdf out.pdf --text "CONFIDENTIAL"
/cf-tools-pdf-watermark input.pdf out.pdf --text "DRAFT" --opacity 0.2 --color "#FF0000"
/cf-tools-pdf-watermark input.pdf out.pdf --pdf watermark.pdf       # single-page overlay
```

Arguments:
1. `pdf-path` (required) — source PDF
2. `output` (required) — destination PDF
3. `--text "STRING"` — text watermark (diagonal, centered, large)
4. `--pdf path` — single-page PDF to stamp on every page
5. `--opacity N` — 0..1, default 0.3
6. `--color "#RRGGBB"` — default `#888888`

Use either `--text` or `--pdf`, not both.

## Required tool — pdftk

`pdftk` is NOT installed by default. Document install:

```bash
brew install pdftk-java        # macOS
sudo apt install pdftk-java    # Debian/Ubuntu
choco install pdftk            # Windows
```

Verify: `pdftk --version` should print `pdftk version 3.x.x`.

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
PDF_PATH="$1"; OUTPUT="$2"; shift 2
WATERMARK_TEXT=""
WATERMARK_PDF=""
OPACITY="0.3"
COLOR="#888888"

while [ $# -gt 0 ]; do
  case "$1" in
    --text) WATERMARK_TEXT="$2"; shift 2 ;;
    --pdf) WATERMARK_PDF="$2"; shift 2 ;;
    --opacity) OPACITY="$2"; shift 2 ;;
    --color) COLOR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ ! -f "$PDF_PATH" ] && { echo "ERROR: not found: $PDF_PATH" >&2; exit 1; }
```

### Step 2 — If text watermark, generate a one-page watermark PDF

```bash
if [ -n "$WATERMARK_TEXT" ]; then
  WATERMARK_PDF="$(mktemp -t watermark.XXXXXX).pdf"
  # Build a tiny HTML and render via Chrome headless (always available on macOS)
  HTML="$(mktemp -t watermark.XXXXXX).html"
  RGB="rgba($((16#${COLOR:1:2})),$((16#${COLOR:3:2})),$((16#${COLOR:5:2})),$OPACITY)"
  cat > "$HTML" <<HTML
<!doctype html><html><head><style>
@page { size: letter; margin: 0; }
body { margin:0; height:100vh; display:flex; align-items:center; justify-content:center; }
.wm { font: bold 96px sans-serif; color: $RGB; transform: rotate(-30deg);
      white-space: nowrap; user-select: none; }
</style></head><body><div class="wm">$WATERMARK_TEXT</div></body></html>
HTML

  CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="$WATERMARK_PDF" "file://$HTML" 2>/dev/null
fi

[ ! -f "$WATERMARK_PDF" ] && { echo "ERROR: no watermark source" >&2; exit 1; }
```

### Step 3 — Apply via pdftk (primary)

```bash
if command -v pdftk >/dev/null 2>&1; then
  pdftk "$PDF_PATH" stamp "$WATERMARK_PDF" output "$OUTPUT"
  METHOD="pdftk"
fi
```

### Step 4 — Fallback to qpdf + pikepdf

```bash
if [ ! -f "$OUTPUT" ] && python3 -c "import pikepdf" 2>/dev/null; then
  python3 - "$PDF_PATH" "$WATERMARK_PDF" "$OUTPUT" <<'PY'
import sys, pikepdf
src, wm_path, dst = sys.argv[1:]
wm = pikepdf.open(wm_path)
wm_page = wm.pages[0]
with pikepdf.open(src) as pdf:
    for p in pdf.pages:
        p.add_overlay(wm_page)
    pdf.save(dst)
PY
  METHOD="pikepdf"
fi
```

### Step 5 — Last resort: ghostscript composite

```bash
if [ ! -f "$OUTPUT" ] && command -v gs >/dev/null 2>&1; then
  # gs requires merging; pdftk-style stamping isn't native — emit guidance
  echo "ERROR: ghostscript cannot stamp watermarks directly." >&2
  echo "Install pdftk: brew install pdftk-java" >&2
  echo "Or install pikepdf: pip install pikepdf" >&2
  exit 1
fi

[ -f "$OUTPUT" ] || { echo "ERROR: no watermark engine available" >&2; exit 1; }
```

### Step 6 — Cleanup + report

```bash
rm -f "$HTML" 2>/dev/null
[ -n "$WATERMARK_TEXT" ] && rm -f "$WATERMARK_PDF"

PAGES=$(pdfinfo "$OUTPUT" 2>/dev/null | awk '/^Pages:/ {print $2}')
echo "✅ Watermarked $PAGES pages → $OUTPUT (via $METHOD)" >&2
```

## Output Contract

```
## PDF watermark

**Source:**    <pdf-path>
**Watermark:** "<text>" | <wm.pdf>
**Output:**    <out.pdf>
**Pages:**     <N>
**Method:**    pdftk | pikepdf
**Opacity:**   <0..1>
**Color:**     <#RRGGBB>
```

## Gotchas

- **`pdftk stamp` requires the watermark PDF to be exactly one page** — multi-page watermarks repeat the first page anyway, but pdftk warns.
- **Different page sizes between source and watermark** — pdftk centers the watermark; sizes that mismatch produce off-center stamps. Match watermark page size to source.
- **`--text` rendered via Chrome headless** depends on Google Chrome being installed. On servers, install `pdftk` and pre-generate the watermark PDF instead.
- **Transparency on text watermark** uses `rgba()` in CSS; PDF preserves the alpha through Chrome's print engine.
- **Background stamp vs. foreground stamp** — `pdftk stamp` puts the watermark ON TOP. For under-content watermarks use `pdftk ... background`.
- **Encrypted PDFs** fail in pdftk. Decrypt first with `qpdf --decrypt --password=PWD in.pdf out.pdf`.

## Cross-Platform Notes

- **macOS**: `brew install pdftk-java` + Google Chrome (for text rendering).
- **Linux**: `apt install pdftk-java`. For text watermark without Chrome, install `pip install pikepdf reportlab` and generate the watermark via reportlab.
- **Windows**: `choco install pdftk` or use pikepdf via Python.
