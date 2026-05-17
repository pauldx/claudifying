---
name: cf-tools-image-heic-to-jpg
description: "Convert Apple HEIC/HEIF photos to JPEG using heif-convert with quality control. Trigger: /cf-tools-image-heic-to-jpg"
trigger: /cf-tools-image-heic-to-jpg
version: 1.0.0
---

# /cf-tools-image-heic-to-jpg

iPhone photos default to HEIC (High Efficiency Image Container). Convert to JPEG for compatibility with non-Apple platforms.

## Usage

```
/cf-tools-image-heic-to-jpg <input.heic>
/cf-tools-image-heic-to-jpg <input.heic> --quality 90
/cf-tools-image-heic-to-jpg <input.heic> --output photo.jpg
/cf-tools-image-heic-to-jpg <directory> --batch
```

Flags:
- `--quality N` — 1-100, default 85
- `--output PATH` — default `<stem>.jpg`
- `--batch` — convert all `*.heic` in a directory
- `--keep-original` — don't delete the source HEIC (default: keep)

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; shift
[ -e "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
QUALITY=85; OUTPUT=""; BATCH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --quality) QUALITY="$2"; shift 2;;
    --output)  OUTPUT="$2"; shift 2;;
    --batch)   BATCH=1; shift;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done
```

### Step 2 — Convert (single file)

```bash
convert_one() {
  local src="$1"
  local stem="${src%.*}"
  local dst="${OUTPUT:-${stem}.jpg}"

  # heif-convert is the libheif tool — handles HEIC and HEIF
  if command -v heif-convert >/dev/null; then
    heif-convert -q "$QUALITY" "$src" "$dst" 2>&1 | grep -v "^$"
  elif command -v magick >/dev/null; then
    # Fallback: magick can read HEIC if compiled with libheif support
    magick "$src" -quality "$QUALITY" "$dst"
  elif command -v sips >/dev/null; then
    # macOS-native fallback
    sips -s format jpeg -s formatOptions "$QUALITY" "$src" --out "$dst" >/dev/null
  else
    echo "ERROR: install heif-convert: brew install libheif"
    exit 2
  fi

  W=$(magick identify -format "%w" "$dst" 2>/dev/null)
  H=$(magick identify -format "%h" "$dst" 2>/dev/null)
  echo "Converted: $src → $dst  (${W}x${H})"
}
```

### Step 3 — Single or batch

```bash
if [ "$BATCH" = "1" ] && [ -d "$INPUT" ]; then
  COUNT=0
  for f in "$INPUT"/*.heic "$INPUT"/*.HEIC "$INPUT"/*.heif; do
    [ -f "$f" ] || continue
    OUTPUT=""   # reset per file
    convert_one "$f"
    COUNT=$((COUNT + 1))
  done
  echo "Batch done: $COUNT files"
else
  convert_one "$INPUT"
fi
```

## Output Contract

```
## HEIC → JPEG conversion

**Input:**     <path>  (HEIC)
**Output:**    <path>  (JPEG, q=<N>)
**Encoder:**   heif-convert | magick | sips
**Dimensions:** <W>x<H>
**Live Photo:** detected (only still frame extracted) | n/a
```

## Verified Test

`magick sample.png test.heic && heif-convert test.heic test_out.jpg` → "File contains 1 image", JPEG 256x256, 5.0KB output.

## Gotchas

- **iPhone Live Photos** are HEIC+MOV pairs — `heif-convert` only extracts the still frame. The companion `.mov` must be handled separately.
- **HEIC with multiple images** (burst mode, depth map) — `heif-convert` writes one JPEG per image with `-N.jpg` suffix.
- **`magick` may not have libheif support** — check with `magick -list format | grep -i heic`. If absent, install via `brew reinstall imagemagick --with-libheif` or use heif-convert directly.
- **EXIF orientation** — heif-convert preserves the orientation tag; viewers without orientation support display sideways. Apply `magick out.jpg -auto-orient out.jpg` after if needed.
- **Wide color (HDR) HEIC** loses HDR data when converted to 8-bit JPEG. Consider AVIF (10-bit) for HDR retention.
- **`sips -s format jpeg`** works as last-resort fallback on macOS but quality control is rough (`formatOptions low|normal|high|best`).

## Cross-Platform Notes

- **macOS**: `brew install libheif imagemagick`. `sips` is the built-in fallback.
- **Linux**: `apt install libheif-examples` (provides heif-convert).
- **Windows**: libheif Windows builds available; or use Microsoft's HEIF Image Extension + ImageMagick.

For batch conversion of an entire iPhone export, `--batch` mode plus `--keep-original` is the recommended invocation.
