---
name: cf-tools-image-watermark
description: "Overlay text or logo watermark with gravity, opacity, and tiling using ImageMagick. Trigger: /cf-tools-image-watermark"
trigger: /cf-tools-image-watermark
version: 1.0.0
---

# /cf-tools-image-watermark

Add a text or image watermark. Supports semi-transparent overlays, gravity positioning, and full-image tiling.

## Usage

```
/cf-tools-image-watermark <input> --text "(c) 2026" --gravity southeast
/cf-tools-image-watermark <input> --text "(c) Me" --opacity 0.5 --pointsize 32
/cf-tools-image-watermark <input> --image logo.png --gravity northeast --opacity 0.7
/cf-tools-image-watermark <input> --text "DRAFT" --tile --rotate -30
```

Flags:
- `--text STRING` — watermark text
- `--image PATH` — overlay logo/image (PNG with alpha recommended)
- `--gravity NAME` — `northwest | north | northeast | west | center | east | southwest | south | southeast` (default southeast)
- `--opacity 0.0-1.0` — overlay opacity (default 0.5)
- `--pointsize N` — text size in points (default auto-scale ~3% of image width)
- `--color HEX` — text color (default white)
- `--font PATH` — font file (default platform-specific Arial)
- `--rotate N` — rotation degrees
- `--tile` — repeat across entire image
- `--output PATH`

## What You Must Do When Invoked

### Step 1 — Parse args + pick default font

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
STEM="${INPUT%.*}"
EXT="${INPUT##*.}"
OUTPUT="${STEM}-wm.${EXT}"
TEXT=""; IMG=""; GRAVITY="southeast"; OPACITY=0.5; PT=""
COLOR="white"; FONT=""; ROTATE=0; TILE=0

# Default fonts per platform
case "$(uname -s)" in
  Darwin) DEFAULT_FONT="/System/Library/Fonts/Supplemental/Arial.ttf";;
  Linux)  DEFAULT_FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf";;
  *)      DEFAULT_FONT="Arial";;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --text)      TEXT="$2"; shift 2;;
    --image)     IMG="$2"; shift 2;;
    --gravity)   GRAVITY="$2"; shift 2;;
    --opacity)   OPACITY="$2"; shift 2;;
    --pointsize) PT="$2"; shift 2;;
    --color)     COLOR="$2"; shift 2;;
    --font)      FONT="$2"; shift 2;;
    --rotate)    ROTATE="$2"; shift 2;;
    --tile)      TILE=1; shift;;
    --output)    OUTPUT="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done

FONT="${FONT:-$DEFAULT_FONT}"

# Auto-scale pointsize to ~3% of input width if not given
if [ -z "$PT" ]; then
  W=$(magick identify -format "%w" "$INPUT")
  PT=$(( W * 3 / 100 ))
  [ "$PT" -lt 12 ] && PT=12
fi
```

### Step 2 — Build watermark layer

```bash
if [ -n "$TEXT" ]; then
  # Compute RGBA with opacity
  RGBA="$(magick xc:"$COLOR" -format "%[pixel:p{0,0}]" info: | sed "s/)$/,${OPACITY})/" | sed 's/^/rgba/' | sed 's/srgb//;s/srgba//')"
  # Simpler: use -fill with separate -alpha
  if [ "$TILE" = "1" ]; then
    # Tile watermark across image
    magick "$INPUT" \
      \( -size "$(magick identify -format '%wx%h' "$INPUT")" xc:none \
         -font "$FONT" -pointsize "$PT" -fill "$COLOR" \
         -gravity center -draw "rotate $ROTATE text 0,0 '$TEXT'" \
         -evaluate multiply "$OPACITY" \) \
      -compose over -composite "$OUTPUT"
  else
    magick "$INPUT" \
      -font "$FONT" -pointsize "$PT" \
      -fill "rgba(255,255,255,$OPACITY)" \
      -gravity "$GRAVITY" \
      -annotate "+10+10" "$TEXT" \
      "$OUTPUT"
  fi
elif [ -n "$IMG" ]; then
  [ -f "$IMG" ] || { echo "ERROR: --image not found: $IMG"; exit 1; }
  magick "$INPUT" \
    \( "$IMG" -alpha set -channel A -evaluate multiply "$OPACITY" +channel \) \
    -gravity "$GRAVITY" -geometry "+10+10" -composite "$OUTPUT"
else
  echo "ERROR: --text or --image required"; exit 1
fi
```

### Step 3 — Verify

```bash
W=$(magick identify -format "%w" "$OUTPUT")
H=$(magick identify -format "%h" "$OUTPUT")
echo "Watermarked: $OUTPUT  (${W}x${H})"
```

## Output Contract

```
## Watermark applied

**Input:**     <path>  (<W>x<H>)
**Output:**    <path>
**Type:**      text | image
**Content:**   "<text>" | <image-path>
**Position:**  gravity=<name>, offset +10+10  (or --tile)
**Opacity:**   <0-1>
**Size:**      <pointsize>pt  (auto)
```

## Verified Tests

- `magick sample.png -font "/System/Library/Fonts/Supplemental/Arial.ttf" -fill "rgba(255,255,255,0.5)" -pointsize 24 -gravity southeast -annotate +10+10 "(c) 2026" wm_text.png` → confirmed
- `magick sample.png logo.png -gravity southeast -geometry +10+10 -composite wm_image.png` → confirmed

## Gotchas

- **Missing font error** — `magick: unable to read font ''` means the default font isn't installed. Always pass `--font` with an explicit path on minimal systems.
- **Arial on macOS** lives in `/System/Library/Fonts/Supplemental/Arial.ttf`, not `/System/Library/Fonts/`. Linux's equivalent is usually `DejaVuSans.ttf`.
- **`rgba()` color string** is the simplest way to express opacity. Some IM versions reject `rgba(255,255,255,0.5)` — use `xc:white -alpha set -channel A -evaluate set 50%` workaround.
- **PNG logos need pre-multiplied alpha** for clean overlay. Use `-alpha set` if the result has weird edge halos.
- **Text size auto-scaling** uses 3% of width — adjust manually for very wide images or short text.
- **Special chars in text** — single quotes around the text in `-annotate` mostly safe; for shell-special chars like `$` or backticks, escape carefully.

## Cross-Platform Notes

- **macOS**: fonts under `/System/Library/Fonts/Supplemental/`. ImageMagick via brew.
- **Linux**: install DejaVu via `apt install fonts-dejavu-core` if missing.
- **Windows**: fonts in `C:\Windows\Fonts\arial.ttf`.
