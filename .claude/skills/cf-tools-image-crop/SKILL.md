---
name: cf-tools-image-crop
description: "Crop images by pixel box, gravity (center/N/S/E/W), or aspect ratio. Trigger: /cf-tools-image-crop"
trigger: /cf-tools-image-crop
version: 1.0.0
---

# /cf-tools-image-crop

Crop a region from an image. Supports raw pixel boxes, gravity-aligned crops, and aspect-ratio-locked crops.

## Usage

```
/cf-tools-image-crop <input> --box 100x100+10+10           # WxH+X+Y
/cf-tools-image-crop <input> --gravity center --size 200x200
/cf-tools-image-crop <input> --aspect 16:9                 # crop to 16:9 from center
/cf-tools-image-crop <input> --aspect 1:1 --gravity north
```

Flags:
- `--box WxH+X+Y` — explicit ImageMagick geometry (X,Y = top-left offset)
- `--gravity NAME` — `northwest | north | northeast | west | center | east | southwest | south | southeast`
- `--size WxH` — target dimensions (used with --gravity)
- `--aspect W:H` — crop to ratio from gravity (default center)
- `--output PATH`

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
STEM="${INPUT%.*}"
EXT="${INPUT##*.}"
OUTPUT="${STEM}-crop.${EXT}"
BOX=""; GRAVITY="center"; SIZE=""; ASPECT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --box)     BOX="$2"; shift 2;;
    --gravity) GRAVITY="$2"; shift 2;;
    --size)    SIZE="$2"; shift 2;;
    --aspect)  ASPECT="$2"; shift 2;;
    --output)  OUTPUT="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done
```

### Step 2 — Compute geometry and crop

```bash
if [ -n "$BOX" ]; then
  # Explicit box, no gravity
  magick "$INPUT" -crop "$BOX" +repage "$OUTPUT"
elif [ -n "$ASPECT" ]; then
  # Aspect-ratio crop: compute largest WxH fitting input that matches ratio
  W=$(magick identify -format "%w" "$INPUT")
  H=$(magick identify -format "%h" "$INPUT")
  AW=$(echo "$ASPECT" | cut -d: -f1)
  AH=$(echo "$ASPECT" | cut -d: -f2)
  # Pick limiting dim
  if [ $((W * AH)) -gt $((H * AW)) ]; then
    NEW_H=$H; NEW_W=$((H * AW / AH))
  else
    NEW_W=$W; NEW_H=$((W * AH / AW))
  fi
  magick "$INPUT" -gravity "$GRAVITY" -crop "${NEW_W}x${NEW_H}+0+0" +repage "$OUTPUT"
elif [ -n "$SIZE" ]; then
  magick "$INPUT" -gravity "$GRAVITY" -crop "${SIZE}+0+0" +repage "$OUTPUT"
else
  echo "ERROR: provide --box, --size, or --aspect"; exit 1
fi
```

### Step 3 — Verify

```bash
W=$(magick identify -format "%w" "$OUTPUT")
H=$(magick identify -format "%h" "$OUTPUT")
echo "Cropped: $OUTPUT (${W}x${H})"
```

## Output Contract

```
## Image crop

**Input:**     <path>  (<W>x<H>)
**Output:**    <path>  (<new W>x<new H>)
**Mode:**      box <geom> | gravity <name> size <WxH> | aspect <W:H>
```

## Verified Tests

- `magick sample.png -crop 100x100+10+10 +repage out.png` → 256x256 → 100x100
- `magick sample.png -gravity center -crop 100x100+0+0 +repage center.png` → 100x100 centered

## Gotchas

- **Always `+repage`** after `-crop` — without it, the cropped image keeps the original canvas page offset, causing later operations to use wrong coordinates.
- **Gravity + offset** — offsets in `WxH+X+Y` are RELATIVE to the gravity anchor, not the image origin. `+0+0` means "no offset from anchor".
- **Crop region outside image** → magick returns the intersection (smaller output), not an error. Sanity-check via `identify` after.
- **GIF crops only frame 0** unless `-coalesce` is applied first.
- **Aspect-ratio crop integer math** can be off-by-one (256x256 → 16:9 = 256x144, leaving 0.something px). Use `+repage` to clean.

## Cross-Platform Notes

- **macOS**: `magick` via `brew install imagemagick`. `sips --cropToHeightWidth H W file` works for center crops only.
- **Linux**: `apt install imagemagick`.
- **Windows**: ImageMagick installer.
