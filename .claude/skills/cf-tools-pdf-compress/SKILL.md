---
name: cf-tools-pdf-compress
description: "Shrink a PDF via ghostscript quality presets (screen/ebook/printer/prepress). Trigger: /cf-tools-pdf-compress"
trigger: /cf-tools-pdf-compress
version: 1.0.0
---

# /cf-tools-pdf-compress

Recompress a PDF to a smaller size using ghostscript's built-in distiller presets. Optionally fall back to `qpdf --object-streams=generate` (lossless object-stream rewrite, modest savings).

## Usage

```
/cf-tools-pdf-compress input.pdf out.pdf                  # default: /ebook
/cf-tools-pdf-compress input.pdf out.pdf screen           # most aggressive
/cf-tools-pdf-compress input.pdf out.pdf ebook            # balanced (default)
/cf-tools-pdf-compress input.pdf out.pdf printer          # 300dpi, larger
/cf-tools-pdf-compress input.pdf out.pdf prepress         # min compression, archival
```

Arguments:
1. `pdf-path` (required) — source PDF
2. `output` (required) — destination PDF
3. `preset` (optional, default `ebook`) — one of `screen | ebook | printer | prepress | default`

Preset → dpi target:
- `screen` — 72dpi images, max compression (~5–20% of original)
- `ebook` — 150dpi, balanced (~20–40%)
- `printer` — 300dpi, light compression (~50–70%)
- `prepress` — 300dpi + color preservation (~80–90%)

## Required tool — ghostscript

`gs` is the primary engine. Document install:

```bash
brew install ghostscript          # macOS
sudo apt install ghostscript      # Debian/Ubuntu
choco install ghostscript         # Windows
```

Verify: `gs --version` should print `10.x.x` or higher.

## What You Must Do When Invoked

### Step 1 — Validate

```bash
PDF_PATH="$1"
OUTPUT="$2"
PRESET="${3:-ebook}"

[ ! -f "$PDF_PATH" ] && { echo "ERROR: not found: $PDF_PATH" >&2; exit 1; }

case "$PRESET" in
  screen|ebook|printer|prepress|default) ;;
  *) echo "ERROR: unknown preset '$PRESET'. Use screen|ebook|printer|prepress" >&2; exit 1 ;;
esac

SIZE_IN=$(wc -c < "$PDF_PATH" | tr -d ' ')
echo "Input: $PDF_PATH ($SIZE_IN bytes)" >&2
echo "Preset: /$PRESET" >&2
```

### Step 2 — Run ghostscript (primary)

```bash
if command -v gs >/dev/null 2>&1; then
  gs -sDEVICE=pdfwrite \
     -dCompatibilityLevel=1.4 \
     -dPDFSETTINGS="/$PRESET" \
     -dNOPAUSE -dQUIET -dBATCH \
     -sOutputFile="$OUTPUT" "$PDF_PATH"
  METHOD="ghostscript /$PRESET"
fi
```

### Step 3 — Fallback to qpdf (lossless object streams)

```bash
if [ ! -f "$OUTPUT" ] && command -v qpdf >/dev/null 2>&1; then
  echo "ghostscript missing — using qpdf lossless rewrite (smaller savings)" >&2
  qpdf --object-streams=generate --compress-streams=y "$PDF_PATH" "$OUTPUT"
  METHOD="qpdf (lossless)"
fi

[ ! -f "$OUTPUT" ] && { echo "ERROR: no compressor available. brew install ghostscript" >&2; exit 1; }
```

### Step 4 — Report ratio

```bash
SIZE_OUT=$(wc -c < "$OUTPUT" | tr -d ' ')
RATIO=$(awk -v in_b="$SIZE_IN" -v out_b="$SIZE_OUT" \
  'BEGIN { printf "%.1f", (out_b/in_b)*100 }')
SAVED=$((SIZE_IN - SIZE_OUT))

echo "✅ Compressed → $OUTPUT" >&2
echo "   $SIZE_IN → $SIZE_OUT bytes (${RATIO}% of original, saved $SAVED bytes)" >&2
echo "   Method: $METHOD" >&2
```

## Output Contract

```
## PDF compression

**Source:**  <pdf-path> (<size_in>)
**Output:**  <out.pdf> (<size_out>)
**Preset:**  /screen | /ebook | /printer | /prepress
**Ratio:**   <pct>% of original
**Saved:**   <bytes>
**Method:**  ghostscript | qpdf
```

## Gotchas

- **`/screen` downsamples images to 72dpi** — text on images becomes pixelated. Use `/ebook` for documents that will be read on screen.
- **Output can be LARGER than input** if the source is already aggressively compressed, or contains many vector elements. Always check ratio.
- **Embedded fonts** are subsetted by default. To force full embedding, add `-dEmbedAllFonts=true -dSubsetFonts=false` (will increase size).
- **`/prepress` preserves CMYK** and is intended for press handoff. Don't use for web distribution.
- **Color-managed PDFs**: `/screen` and `/ebook` convert to sRGB. To preserve ICC profiles, use `/printer` or `/prepress`.
- **Tagged / accessibility PDFs lose tags** through ghostscript. For accessibility-preserving compression, use `pikepdf` with manual image recompression.
- **Encrypted PDFs**: ghostscript will refuse unless you pass `-dPassword=PWD`.
- **`-dCompatibilityLevel=1.4`** ensures broad reader compatibility. Bump to 1.7 for transparency-heavy modern PDFs.

## Cross-Platform Notes

- **macOS**: `brew install ghostscript`. `qpdf` as fallback: `brew install qpdf`.
- **Linux**: `apt install ghostscript qpdf`.
- **Windows**: ghostscript installer from `https://ghostscript.com/releases/`.
