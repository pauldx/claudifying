---
name: cf-tools-image-favicon
description: "Generate favicon.ico + PNG variants (16,32,180,192) and manifest.json snippet from any source image. Trigger: /cf-tools-image-favicon"
trigger: /cf-tools-image-favicon
version: 1.0.0
---

# /cf-tools-image-favicon

Produce a complete favicon set from a single source PNG/SVG: multi-resolution `.ico`, PNG variants for modern browsers, Apple touch icon, and a `manifest.json` snippet to paste into your web app.

## Usage

```
/cf-tools-image-favicon <input.png>
/cf-tools-image-favicon <input.svg> --output-dir ./public
/cf-tools-image-favicon <input.png> --bg "#ffffff"     # background for non-transparent variants
```

Flags:
- `--output-dir DIR` — directory to write outputs (default: `./favicons/`)
- `--bg COLOR` — fill color for Apple touch icon (Apple ignores PNG alpha; default `#ffffff`)

## What You Must Do When Invoked

### Step 1 — Validate input and prep output dir

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
OUTDIR="./favicons"
BG="#ffffff"

while [ $# -gt 0 ]; do
  case "$1" in
    --output-dir) OUTDIR="$2"; shift 2;;
    --bg)         BG="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done

mkdir -p "$OUTDIR"

# Source must be at least 512x512 (or be SVG) for clean downscaling
SRC_W=$(magick identify -format "%w" "$INPUT" 2>/dev/null || echo "512")
if [ "$SRC_W" -lt 512 ] 2>/dev/null && [ "${INPUT##*.}" != "svg" ]; then
  echo "WARN: source is ${SRC_W}px — recommend >=512px for crisp favicons"
fi
```

### Step 2 — Generate multi-resolution favicon.ico

```bash
magick "$INPUT" -define icon:auto-resize=16,32,48 "$OUTDIR/favicon.ico"
```

### Step 3 — Generate PNG variants

```bash
# Standard browser tabs
magick "$INPUT" -resize 16x16   "$OUTDIR/favicon-16x16.png"
magick "$INPUT" -resize 32x32   "$OUTDIR/favicon-32x32.png"

# Apple touch icon — flatten on background (iOS strips alpha)
magick "$INPUT" -resize 180x180 -background "$BG" -alpha remove -alpha off "$OUTDIR/apple-touch-icon.png"

# PWA / Android home screen
magick "$INPUT" -resize 192x192 "$OUTDIR/android-chrome-192x192.png"
magick "$INPUT" -resize 512x512 "$OUTDIR/android-chrome-512x512.png"
```

### Step 4 — Write manifest.json snippet

```bash
cat > "$OUTDIR/site.webmanifest" <<'EOF'
{
  "name": "",
  "short_name": "",
  "icons": [
    {
      "src": "/android-chrome-192x192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/android-chrome-512x512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ],
  "theme_color": "#ffffff",
  "background_color": "#ffffff",
  "display": "standalone"
}
EOF
```

### Step 5 — Print HTML head snippet

```bash
cat <<'EOF'

--- Paste into <head> ---
<link rel="icon" href="/favicon.ico" sizes="any">
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
EOF
```

## Output Contract

```
## Favicon set generated

**Source:**    <path>  (<W>x<H>)
**Output dir:** <path>
**Files:**
  - favicon.ico         (16, 32, 48 multi-res)
  - favicon-16x16.png
  - favicon-32x32.png
  - apple-touch-icon.png (180x180, alpha removed)
  - android-chrome-192x192.png
  - android-chrome-512x512.png
  - site.webmanifest
**HTML snippet:** (printed above)
```

## Verified Tests

- `magick sample.png -define icon:auto-resize=16,32,48 favicon.ico` → multi-frame ICO confirmed (3 frames: 16x16, 32x32, 48x48)
- Each PNG variant generated correctly: 16, 32, 180, 192 px confirmed via `magick identify`

## Gotchas

- **Apple touch icons must NOT have transparency** — iOS renders alpha as black. Always `-background <color> -alpha remove -alpha off`.
- **SVG input is best** — vector source means crisp output at every size. For PNG source, start from >=512px to avoid blur at 192/512 scales.
- **`favicon.ico` with too many sizes bloats the file** — 16/32/48 covers all browsers. Don't include 256x256 in ICO; use separate PNG instead.
- **PWA `theme_color` and `background_color`** in manifest control splash screen — leave as `#ffffff` placeholders for user to customize.
- **`auto-resize` is ImageMagick-specific** — `convert` (v6) also supports it; other tools (e.g. png2ico) don't.

## Cross-Platform Notes

- **macOS / Linux / Windows**: `magick` from `brew install imagemagick` / `apt install imagemagick`.
- For SVG source, see `/cf-tools-image-convert-svg-png` first to rasterize at 512px, then feed into this skill.
