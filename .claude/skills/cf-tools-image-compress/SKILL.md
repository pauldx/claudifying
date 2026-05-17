---
name: cf-tools-image-compress
description: "Lossy/lossless compression with pngquant, mozjpeg, cwebp for max savings. Trigger: /cf-tools-image-compress"
trigger: /cf-tools-image-compress
version: 1.0.0
---

# /cf-tools-image-compress

Reduce file size while keeping visual quality. Uses format-specific best-of-breed encoders:
- **PNG** → `pngquant` (lossy palette quantization, ~70% smaller)
- **JPEG** → `cjpeg` (mozjpeg, ~10-20% smaller than libjpeg)
- **WebP** → `cwebp` (Google's encoder)

## Usage

```
/cf-tools-image-compress <input>
/cf-tools-image-compress <input> --quality 75
/cf-tools-image-compress <input> --quality 65-80     # pngquant range
/cf-tools-image-compress <input> --output small.png
/cf-tools-image-compress <input> --lossless          # PNG/WebP only
```

Flags:
- `--quality N` or `--quality MIN-MAX` — 1-100, default `65-80`
- `--lossless` — for PNG (skips pngquant) and WebP (-lossless flag)
- `--output PATH` — default overwrites input in `-min.<ext>` sidecar

## What You Must Do When Invoked

### Step 1 — Detect format

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
STEM="${INPUT%.*}"
EXT="${INPUT##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
OUTPUT="${STEM}-min.${EXT}"
QUALITY="65-80"
LOSSLESS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --quality)  QUALITY="$2"; shift 2;;
    --output)   OUTPUT="$2"; shift 2;;
    --lossless) LOSSLESS=1; shift;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done
```

### Step 2 — Dispatch to encoder

```bash
case "$EXT_LOWER" in
  png)
    if [ "$LOSSLESS" = "1" ]; then
      # magick -strip removes metadata; oxipng (if available) better
      magick "$INPUT" -strip "$OUTPUT"
    else
      pngquant --quality="$QUALITY" --force --output "$OUTPUT" "$INPUT"
    fi
    ;;
  jpg|jpeg)
    # cjpeg takes PPM input — pipe through magick
    Q=$(echo "$QUALITY" | sed 's/-.*//')   # take min if range given
    magick "$INPUT" ppm:- | cjpeg -quality "$Q" -optimize > "$OUTPUT"
    ;;
  webp)
    Q=$(echo "$QUALITY" | sed 's/-.*//')
    if [ "$LOSSLESS" = "1" ]; then
      cwebp -lossless -quiet "$INPUT" -o "$OUTPUT"
    else
      cwebp -q "$Q" -quiet "$INPUT" -o "$OUTPUT"
    fi
    ;;
  *)
    # Generic fallback via magick
    Q=$(echo "$QUALITY" | sed 's/-.*//')
    magick "$INPUT" -quality "$Q" -strip "$OUTPUT"
    ;;
esac
```

### Step 3 — Report savings

```bash
SZ_IN=$(stat -f %z "$INPUT" 2>/dev/null || stat -c %s "$INPUT")
SZ_OUT=$(stat -f %z "$OUTPUT" 2>/dev/null || stat -c %s "$OUTPUT")
PCT=$(( (SZ_IN - SZ_OUT) * 100 / SZ_IN ))
echo "Compressed: ${SZ_IN}B → ${SZ_OUT}B (${PCT}% smaller) → $OUTPUT"
```

## Output Contract

```
## Image compression

**Input:**    <path>  (<KB>)
**Output:**   <path>  (<KB>)
**Encoder:**  pngquant | cjpeg (mozjpeg) | cwebp | magick
**Mode:**     lossy q=<N> | lossless
**Savings:**  <%> smaller
```

## Verified Tests

- `pngquant --quality=65-80 sample.png -o compressed.png` → 1.5KB → 0.9KB (40% smaller)
- `magick sample.jpg ppm:- | cjpeg -quality 75 > compressed.jpg` → 3.4KB → 2.5KB
- `cwebp -q 75 sample.png -o compressed.webp` confirmed

## Gotchas

- **`cjpeg` requires PPM/PGM input** — pipe through `magick "$INPUT" ppm:-` first; raw JPEG passed directly fails with "Unrecognized input file format".
- **pngquant exits non-zero (98)** when it can't hit the quality range — re-run with wider range like `40-90`.
- **`--quality MIN-MAX`** is pngquant syntax; for cjpeg/cwebp the script extracts the MIN value as a single int.
- **Animated PNG/GIF** will lose animation through pngquant — preserve animation by using `gifsicle` or keeping the GIF as-is.
- **Lossless PNG via `magick -strip`** only saves a few bytes (metadata); for real lossless PNG crunching use `oxipng` or `zopflipng` (not in base toolchain).

## Cross-Platform Notes

- **macOS**: `brew install pngquant mozjpeg webp`. Note mozjpeg installs to `/usr/local/opt/mozjpeg/bin/cjpeg` — make sure that's first on PATH (or libjpeg's `cjpeg` will be used and savings are smaller).
- **Linux**: `apt install pngquant libjpeg-turbo-progs webp` (mozjpeg may need source build).
- **Windows**: pngquant standalone .exe; mozjpeg as `cjpeg.exe`.
