---
name: cf-tools-image-resize
description: "Resize raster images by width, percent, or max-dim using ImageMagick. Trigger: /cf-tools-image-resize"
trigger: /cf-tools-image-resize
version: 1.0.0
---

# /cf-tools-image-resize

Resize PNG/JPG/WebP/AVIF/GIF/BMP via ImageMagick 7. One generic, flag-driven interface — no separate skills per resize mode.

## Usage

```
/cf-tools-image-resize <input> --width 800
/cf-tools-image-resize <input> --height 600
/cf-tools-image-resize <input> --percent 50
/cf-tools-image-resize <input> --max-dim 1024      # shrink only if larger
/cf-tools-image-resize <input> --width 800 --output resized.png
```

Flags:
- `--width N` — target width in px (height auto by aspect)
- `--height N` — target height in px (width auto by aspect)
- `--percent N` — scale percentage (e.g. `50` = half size)
- `--max-dim N` — cap longest edge at N, only shrinks (`>` modifier)
- `--output PATH` — explicit destination (default `<stem>-resized.<ext>`)
- `--quality N` — JPEG/WebP quality 1-100 (default 85)

## What You Must Do When Invoked

### Step 1 — Validate input and pick mode

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found: $INPUT"; exit 1; }
EXT="${INPUT##*.}"
STEM="${INPUT%.*}"
OUTPUT="${STEM}-resized.${EXT}"
QUALITY=85
MODE=""; VAL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --width)   MODE=width; VAL="$2"; shift 2;;
    --height)  MODE=height; VAL="$2"; shift 2;;
    --percent) MODE=percent; VAL="$2"; shift 2;;
    --max-dim) MODE=maxdim; VAL="$2"; shift 2;;
    --output)  OUTPUT="$2"; shift 2;;
    --quality) QUALITY="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done
[ -z "$MODE" ] && { echo "ERROR: pick --width / --height / --percent / --max-dim"; exit 1; }
```

### Step 2 — Build ImageMagick geometry string

```bash
case "$MODE" in
  width)   GEOM="${VAL}x";;
  height)  GEOM="x${VAL}";;
  percent) GEOM="${VAL}%";;
  maxdim)  GEOM="${VAL}x${VAL}>";;   # > = only shrink, preserve aspect
esac

magick "$INPUT" -resize "$GEOM" -quality "$QUALITY" "$OUTPUT"
```

### Step 3 — Verify and report

```bash
W=$(magick identify -format "%w" "$OUTPUT")
H=$(magick identify -format "%h" "$OUTPUT")
SZ=$(stat -f %z "$OUTPUT" 2>/dev/null || stat -c %s "$OUTPUT")
echo "Resized: $OUTPUT  (${W}x${H}, $((SZ/1024))KB)"
```

## Output Contract

```
## Image resize

**Input:**   <path>  (<orig W>x<orig H>)
**Output:**  <path>  (<new W>x<new H>)
**Mode:**    width|height|percent|max-dim = <value>
**Size:**    <old KB> → <new KB>  (<delta>%)
```

## Verified Test

`magick sample.png -resize 128x128 out.png` → 256x256 → 128x128 PNG, 1.7KB. `-resize 50%` and `-resize 512x512\>` (max-dim) confirmed.

## Gotchas

- `>` modifier (e.g. `1024x1024>`) must be **shell-escaped** as `1024x1024\>` or quoted, else shell redirects.
- ImageMagick 7 uses `magick`, not deprecated `convert`. `convert` may still resolve on systems but emits deprecation warnings.
- Resizing GIFs collapses animation to first frame unless you use `-coalesce` first.
- AVIF/WebP outputs respect `-quality` flag; PNG does not (PNG is lossless — use cf-tools-image-compress for size reduction).
- Resize alone won't reduce file size much for already-tiny images; pair with cf-tools-image-compress.

## Cross-Platform Notes

- **macOS**: `magick` via `brew install imagemagick`. `sips -Z <max> file` is a built-in fallback that caps the longest edge but supports fewer formats (no AVIF/WebP).
- **Linux**: `apt install imagemagick` (v7 via official tarball; distro packages may still be v6 — `convert` works there).
- **Windows**: ImageMagick installer from imagemagick.org.

If `magick` is missing on macOS, fall back to `sips -Z $VAL "$INPUT" --out "$OUTPUT"` for `--max-dim` mode only.
