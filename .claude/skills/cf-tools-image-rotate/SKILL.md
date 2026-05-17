---
name: cf-tools-image-rotate
description: "Rotate, flip, or flop images by arbitrary degrees or 90-degree increments. Trigger: /cf-tools-image-rotate"
trigger: /cf-tools-image-rotate
version: 1.0.0
---

# /cf-tools-image-rotate

Rotate by any angle or apply mirror flips (horizontal/vertical).

## Usage

```
/cf-tools-image-rotate <input> --degrees 90
/cf-tools-image-rotate <input> --degrees -45 --background white
/cf-tools-image-rotate <input> --flip                   # vertical mirror
/cf-tools-image-rotate <input> --flop                   # horizontal mirror
/cf-tools-image-rotate <input> --auto-orient            # apply EXIF orientation
```

Flags:
- `--degrees N` — rotation in degrees (positive = clockwise). 90/180/270 are lossless.
- `--flip` — mirror vertically (top↔bottom)
- `--flop` — mirror horizontally (left↔right)
- `--auto-orient` — apply EXIF orientation tag then strip it (common for phone photos)
- `--background COLOR` — fill color for non-90° rotations (default transparent for PNG, white for JPG)
- `--output PATH`

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
STEM="${INPUT%.*}"
EXT="${INPUT##*.}"
OUTPUT="${STEM}-rot.${EXT}"
DEGREES=""; FLIP=0; FLOP=0; AUTO=0; BG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --degrees)    DEGREES="$2"; shift 2;;
    --flip)       FLIP=1; shift;;
    --flop)       FLOP=1; shift;;
    --auto-orient) AUTO=1; shift;;
    --background) BG="$2"; shift 2;;
    --output)     OUTPUT="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done
```

### Step 2 — Build magick pipeline

```bash
ARGS=()
[ "$AUTO" = "1" ] && ARGS+=(-auto-orient)
[ "$FLIP" = "1" ] && ARGS+=(-flip)
[ "$FLOP" = "1" ] && ARGS+=(-flop)
if [ -n "$DEGREES" ]; then
  # Set background BEFORE rotation so triangular fill area uses correct color
  if [ -n "$BG" ]; then
    ARGS+=(-background "$BG")
  elif [ "$EXT" = "jpg" ] || [ "$EXT" = "jpeg" ]; then
    ARGS+=(-background white)
  else
    ARGS+=(-background "rgba(0,0,0,0)")
  fi
  ARGS+=(-rotate "$DEGREES")
fi

magick "$INPUT" "${ARGS[@]}" "$OUTPUT"
```

### Step 3 — Verify

```bash
W=$(magick identify -format "%w" "$OUTPUT")
H=$(magick identify -format "%h" "$OUTPUT")
echo "Output: $OUTPUT  (${W}x${H})"
```

## Output Contract

```
## Image rotate/flip

**Input:**    <path>  (<W>x<H>)
**Output:**   <path>  (<new W>x<new H>)
**Ops:**      <auto-orient,> <flip,> <flop,> <rotate N°>
**Lossless:** yes  (90/180/270, flip, flop)  |  no  (arbitrary angle re-renders)
```

## Verified Tests

- `magick sample.png -rotate 90 rot90.png` → 256x256 PNG preserved
- `magick sample.png -flop flop.png` → confirmed
- `magick sample.png -flip flip.png` → confirmed

## Gotchas

- **90/180/270 are lossless for JPEG only via `jpegtran -rotate N`** — `magick -rotate 90 on JPEG re-encodes and loses quality. For JPEG add `--lossless-jpeg` flag and route to `jpegtran -perfect -rotate N`.
- **`-flip` is vertical, `-flop` is horizontal** — easy to confuse. Mnemonic: flIp = vertIcal axis flipped.
- **Arbitrary angles add transparent/colored corners** — for JPEG default is white, for PNG transparent. Override with `--background`.
- **EXIF orientation gotcha** — phone photos store rotation as EXIF data. `--auto-orient` reads the tag and physically rotates pixels, then resets the tag.
- **Background color must precede `-rotate`** in the magick argument order — IM is order-dependent.

## Cross-Platform Notes

- **macOS**: `magick` (brew imagemagick). `sips -r 90 file --out out.png` for lossless 90° increments.
- **Linux**: `apt install imagemagick libjpeg-turbo-progs` (jpegtran).
- **Windows**: ImageMagick installer; jpegtran via libjpeg-turbo Windows binary.

For lossless JPEG rotation use `jpegtran -perfect -rotate 90 input.jpg > output.jpg` instead of magick.
