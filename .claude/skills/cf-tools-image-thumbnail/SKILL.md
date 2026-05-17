---
name: cf-tools-image-thumbnail
description: "Generate fast, web-optimized thumbnails with smart-resize and sharpening. Trigger: /cf-tools-image-thumbnail"
trigger: /cf-tools-image-thumbnail
version: 1.0.0
---

# /cf-tools-image-thumbnail

`magick -thumbnail` is purpose-built for fast downscaling: it strips most metadata, uses a lower-precision colorspace, and applies mild sharpening — producing smaller, crisper thumbnails than `-resize`.

## Usage

```
/cf-tools-image-thumbnail <input> --size 200
/cf-tools-image-thumbnail <input> --size 200x200 --crop
/cf-tools-image-thumbnail <input> --size 400 --quality 75
/cf-tools-image-thumbnail <input> --size 200 --format webp
```

Flags:
- `--size N` or `--size WxH` — max dimension or explicit W×H (default `200`)
- `--crop` — center-crop to exact square/rectangle (otherwise preserves aspect)
- `--quality N` — JPEG/WebP quality (default 80, suitable for previews)
- `--format png|jpg|webp` — output format (default matches input)
- `--output PATH`

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
STEM="${INPUT%.*}"
EXT="${INPUT##*.}"
SIZE="200"; CROP=0; QUALITY=80; FORMAT="$EXT"; OUTPUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --size)    SIZE="$2"; shift 2;;
    --crop)    CROP=1; shift;;
    --quality) QUALITY="$2"; shift 2;;
    --format)  FORMAT="$2"; shift 2;;
    --output)  OUTPUT="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done

[ -z "$OUTPUT" ] && OUTPUT="${STEM}-thumb.${FORMAT}"

# Normalize size string (200 → 200x200)
if [[ "$SIZE" != *x* ]]; then
  GEOM="${SIZE}x${SIZE}"
else
  GEOM="$SIZE"
fi
```

### Step 2 — Run thumbnail pipeline

```bash
if [ "$CROP" = "1" ]; then
  # Cover-style: fill the box, crop overflow
  magick "$INPUT" -thumbnail "${GEOM}^" -gravity center -extent "$GEOM" \
    -unsharp 0x.5 -quality "$QUALITY" -strip "$OUTPUT"
else
  # Contain-style: fit within box, preserve aspect
  magick "$INPUT" -thumbnail "$GEOM" -unsharp 0x.5 -quality "$QUALITY" -strip "$OUTPUT"
fi
```

### Step 3 — Verify and report savings

```bash
W=$(magick identify -format "%w" "$OUTPUT")
H=$(magick identify -format "%h" "$OUTPUT")
SZ_IN=$(stat -f %z "$INPUT" 2>/dev/null || stat -c %s "$INPUT")
SZ_OUT=$(stat -f %z "$OUTPUT" 2>/dev/null || stat -c %s "$OUTPUT")
PCT=$(( SZ_OUT * 100 / SZ_IN ))
echo "Thumbnail: $OUTPUT  (${W}x${H}, ${SZ_OUT}B = ${PCT}% of original)"
```

## Output Contract

```
## Thumbnail

**Input:**    <path>  (<W>x<H>, <KB>)
**Output:**   <path>  (<W>x<H>, <KB>)
**Mode:**     contain | cover (cropped)
**Sharpening:** -unsharp 0x.5
**Savings:**  <orig - new> bytes  (<%>)
```

## Verified Test

`magick large.png -thumbnail 200x200 -unsharp 0x.5 thumb.png` → 2048x2048 PNG (20.3MB) → 200x200 PNG (63KB).

## Gotchas

- **`-thumbnail` vs `-resize`** — `-thumbnail` strips metadata + uses faster sampling. ~3-5× faster on large inputs.
- **`^` modifier on geometry** = "fill, then crop". `200x200^` means "make sure both dims >= 200". Pair with `-extent` to crop overflow.
- **`-unsharp 0x.5`** is a gentle sharpen counteracting blur from downscaling. Skip for graphics with hard edges (logos, screenshots).
- **`-strip` removes color profile** — for photo galleries that need wide-gamut display, omit `-strip` and accept larger file size.
- **JPEG thumbnails embedded in EXIF** — phone photos already include small thumbnails. `exiftool -ThumbnailImage -b photo.jpg > thumb.jpg` extracts that instead of re-encoding.
- **Animated GIF → static thumbnail** — magick takes frame 0 by default. For animated thumbs (uncommon) use `-coalesce` and accept the file-size penalty.

## Cross-Platform Notes

- **macOS / Linux / Windows**: `magick` via ImageMagick install. No alternative tool matches the speed of `-thumbnail` for batch jobs.
- **sips fallback (macOS only)**: `sips -Z 200 file --out thumb.png` is fast but no sharpening, no metadata strip.
