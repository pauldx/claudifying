---
name: cf-tools-productivity-qr-decode
description: "Decode a QR code image to its text payload using zbarimg. Trigger: /cf-tools-productivity-qr-decode"
trigger: /cf-tools-productivity-qr-decode
version: 1.0.0
---

# /cf-tools-productivity-qr-decode

Read a QR code from a PNG/JPG/etc and print the decoded payload. Uses `zbarimg` from the `zbar` library — handles rotated, noisy, and multi-code images.

## Usage

```
/cf-tools-productivity-qr-decode /path/to/qr.png
/cf-tools-productivity-qr-decode /path/to/photo.jpg --raw
/cf-tools-productivity-qr-decode ./screenshot.png --all
```

Arguments:
1. `image-path` (required) — PNG, JPG, GIF, BMP, TIFF
2. `--raw` (optional) — print only the payload, no `QR-Code:` prefix
3. `--all` (optional) — emit every code found (default behavior already lists all)

## What You Must Do When Invoked

### Step 1 — Verify zbarimg is installed

```bash
if ! command -v zbarimg >/dev/null 2>&1; then
  echo "ERROR: zbarimg not installed."
  echo "Install: brew install zbar  (macOS)"
  echo "         sudo apt install zbar-tools  (Debian/Ubuntu)"
  exit 2
fi
```

### Step 2 — Validate input

```bash
IMG="$1"
[ -f "$IMG" ] || { echo "ERROR: file not found: $IMG"; exit 1; }

# Friendly format check
case "${IMG##*.}" in
  png|PNG|jpg|JPG|jpeg|JPEG|gif|GIF|bmp|BMP|tiff|TIFF|tif|TIF) ;;
  *) echo "WARN: unusual extension; zbarimg may still try" ;;
esac
```

### Step 3 — Decode

```bash
# -q quiet status; --raw drops the "QR-Code:" prefix
if [ "$RAW" = "1" ]; then
  zbarimg --raw -q "$IMG"
else
  zbarimg -q "$IMG"
fi
RC=$?

if [ $RC -ne 0 ]; then
  echo "ERROR: no QR code detected (or unsupported format)."
  echo "Tips: try a higher-resolution scan; ensure adequate contrast; crop tightly."
  exit 1
fi
```

### Step 4 — Report

```bash
echo ""
echo "✅ Decoded successfully"
echo "   Image:  $IMG"
echo "   Codes:  <line-count of output>"
```

## Output Contract

```
## QR decode
**Image:**     <abs-path>
**Codes:**     <N>
**Type(s):**   QR-Code | CODE-128 | EAN-13 | …
**Payload(s):**
  1. <text-1>
  2. <text-2>
```

## Gotchas

- **`zbarimg` not found**: package is `zbar-tools` on Debian/Ubuntu, not `zbar`. macOS Homebrew is `brew install zbar`.
- **Returns non-zero with no output**: low contrast or blurry image. Recommend cropping closer to the code and re-running.
- **Decodes non-QR formats too**: zbar handles CODE-128, EAN, UPC, etc. Output prefix tells you which (e.g., `CODE-128:`). Use `--raw` to strip.
- **macOS Preview screenshots in HEIC**: convert to PNG first via `sips` or `heif-convert`.
- **PDFs**: zbarimg can't read PDFs. Rasterize a page first (`pdftoppm`) then decode.

## Cross-Platform Notes

- **macOS**: `brew install zbar`
- **Linux**: `sudo apt install zbar-tools` / `sudo dnf install zbar`
- **Windows**: prefer WSL; native Windows builds exist but are unmaintained.
- Verify: `qrencode "test" -o /tmp/t.png && zbarimg --raw -q /tmp/t.png` should print `test`.
