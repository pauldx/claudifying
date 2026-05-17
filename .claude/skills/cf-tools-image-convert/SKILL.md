---
name: cf-tools-image-convert
description: "Convert between PNG, JPG, WebP, AVIF, GIF, BMP using best-of-breed encoders. Trigger: /cf-tools-image-convert"
trigger: /cf-tools-image-convert
version: 1.0.0
---

# /cf-tools-image-convert

Convert raster images across formats. Uses `magick` for most formats but routes WebP through `cwebp` and AVIF through `avifenc` for better quality at the same bitrate.

## Usage

```
/cf-tools-image-convert <input> --to png
/cf-tools-image-convert <input> --to jpg --quality 90
/cf-tools-image-convert <input> --to webp --quality 80
/cf-tools-image-convert <input> --to avif --quality 60
/cf-tools-image-convert <input> --to png --output out.png
```

Flags:
- `--to FORMAT` — one of `png | jpg | webp | avif | gif | bmp`
- `--quality N` — 1-100 (lossy formats only; default 85)
- `--output PATH` — explicit output (default `<stem>.<format>`)

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found: $INPUT"; exit 1; }
STEM="${INPUT%.*}"
FORMAT=""; QUALITY=85; OUTPUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --to)      FORMAT="$2"; shift 2;;
    --quality) QUALITY="$2"; shift 2;;
    --output)  OUTPUT="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done
[ -z "$FORMAT" ] && { echo "ERROR: --to required"; exit 1; }
[ -z "$OUTPUT" ] && OUTPUT="${STEM}.${FORMAT}"
```

### Step 2 — Route to best encoder for target format

```bash
case "$FORMAT" in
  webp)
    # cwebp gives better quality/size than magick's WebP encoder
    if command -v cwebp >/dev/null; then
      cwebp -quiet -q "$QUALITY" "$INPUT" -o "$OUTPUT"
    else
      magick "$INPUT" -quality "$QUALITY" "$OUTPUT"
    fi
    ;;
  avif)
    # avifenc (libavif) tuned for quality
    if command -v avifenc >/dev/null; then
      # Map quality 1-100 to QP-equivalent min/max (lower QP = higher quality)
      QMIN=$(( (100 - QUALITY) / 3 ))
      QMAX=$(( (100 - QUALITY) / 2 ))
      avifenc --min "$QMIN" --max "$QMAX" "$INPUT" "$OUTPUT" >/dev/null
    else
      magick "$INPUT" -quality "$QUALITY" "$OUTPUT"
    fi
    ;;
  jpg|jpeg)
    magick "$INPUT" -quality "$QUALITY" -strip "$OUTPUT"
    ;;
  png|gif|bmp)
    magick "$INPUT" "$OUTPUT"
    ;;
  *)
    echo "ERROR: unsupported --to $FORMAT"; exit 1;;
esac
```

### Step 3 — Verify and report

```bash
[ -f "$OUTPUT" ] || { echo "ERROR: output not written"; exit 1; }
W=$(magick identify -format "%w" "$OUTPUT")
H=$(magick identify -format "%h" "$OUTPUT")
SZ_IN=$(stat -f %z "$INPUT" 2>/dev/null || stat -c %z "$INPUT")
SZ_OUT=$(stat -f %z "$OUTPUT" 2>/dev/null || stat -c %z "$OUTPUT")
echo "Converted: $INPUT → $OUTPUT  (${W}x${H}, ${SZ_IN}B → ${SZ_OUT}B)"
```

## Output Contract

```
## Image format conversion

**Input:**    <path>  (<format>, <W>x<H>, <KB>)
**Output:**   <path>  (<format>, <KB>)
**Encoder:**  magick | cwebp | avifenc
**Quality:**  <N>  (lossless for PNG/GIF/BMP)
**Ratio:**    <new/old %>
```

## Verified Tests

- `magick sample.png conv.jpg` → 256x256 JPEG, 6.4KB
- `magick sample.png conv.gif` → 256x256 GIF, 1.5KB
- `cwebp -q 80 sample.png -o conv.webp` → 1.8KB
- `avifenc --min 30 --max 35 sample.png conv.avif` → 1.7KB

## Gotchas

- **avifenc q-mapping is inverted** — `--min`/`--max` are QP values (0=lossless, 63=worst). The mapping above gives reasonable defaults.
- **PNG→JPG loses alpha** — JPG has no transparency; magick fills with black by default. Add `-background white -alpha remove -alpha off` for a white background.
- **GIF conversion drops frames** unless input is already a single frame. For animated GIFs use `magick input.gif[0]` to grab frame 0 explicitly.
- **AVIF encoding is slow** — multi-second per image. Use `--quality 60` for fast web-grade output.
- **Don't trust file extension alone** — magick reads the actual file header. If you rename `foo.png` to `foo.jpg`, magick sees it's really PNG.

## Cross-Platform Notes

- **macOS**: `brew install imagemagick webp libavif`. `sips -s format jpeg ... --out ...` is a built-in fallback.
- **Linux**: `apt install imagemagick webp libavif-bin`.
- **Windows**: Use ImageMagick installer; cwebp/avifenc available as standalone Windows binaries.

If `cwebp`/`avifenc` are missing, fall through to `magick` — quality difference is small for most use cases.
