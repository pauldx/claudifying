---
name: tools-image-convert-svg-png
description: "Convert SVG to retina PNG via Chrome headless. Trigger: /tools-image-convert-svg-png"
trigger: /tools-image-convert-svg-png
version: 1.0.0
---

# /tools-image-convert-svg-png

Convert any SVG file to a crisp PNG. Preserves the SVG's native aspect ratio. Default 2× scale (retina). No copy of the SVG into a square thumbnail. No rasterization blur.

## Usage

```
/tools-image-convert-svg-png /path/to/file.svg
/tools-image-convert-svg-png /path/to/file.svg 3        # 3× scale
/tools-image-convert-svg-png /path/to/file.svg 2 out.png   # explicit output
```

Arguments:
1. `svg-path` (required) — absolute or relative path to source SVG
2. `scale` (optional, default `2`) — device scale factor for retina quality
3. `output` (optional, default `<svg-stem>.png` in same dir) — output PNG path

## Why Chrome Headless First

Tested fallback chain on macOS:

| Tool | Aspect ratio | Quality | Available |
|---|---|---|---|
| Chrome headless | ✅ preserved | ✅ vector-perfect | ships with Google Chrome |
| `rsvg-convert` | ✅ preserved | ✅ vector-perfect | needs `brew install librsvg` |
| `qlmanage -t` | ❌ forced square | ⚠️ thumbnail letterbox | macOS built-in |
| `sips` | ❌ no SVG support | — | macOS built-in (raster only) |

Chrome wins because it ships with most dev machines and renders SVG with the same engine the user sees in their browser.

## What You Must Do When Invoked

### Step 1 — Validate input

```bash
SVG_PATH="<arg1>"
SCALE="${2:-2}"

if [ ! -f "$SVG_PATH" ]; then
  echo "ERROR: SVG file not found: $SVG_PATH"
  exit 1
fi

# Resolve to absolute path
SVG_ABS="$(cd "$(dirname "$SVG_PATH")" && pwd)/$(basename "$SVG_PATH")"

# Default output: same dir, same stem, .png
OUTPUT="${3:-${SVG_ABS%.svg}.png}"
echo "Source:  $SVG_ABS"
echo "Scale:   ${SCALE}x"
echo "Output:  $OUTPUT"
```

### Step 2 — Read SVG viewBox / width-height for aspect ratio

```bash
# Extract intrinsic dimensions from viewBox or width/height attrs
DIMS=$(python3 - "$SVG_ABS" <<'PY'
import sys, re
svg = open(sys.argv[1]).read()
# Try viewBox first (most reliable)
vb = re.search(r'viewBox\s*=\s*"([^"]+)"', svg)
if vb:
    parts = vb.group(1).split()
    if len(parts) == 4:
        w, h = float(parts[2]), float(parts[3])
        print(f"{int(w)} {int(h)}")
        sys.exit(0)
# Fallback: width/height attrs (strip units)
wm = re.search(r'<svg[^>]*\swidth\s*=\s*"([\d.]+)', svg)
hm = re.search(r'<svg[^>]*\sheight\s*=\s*"([\d.]+)', svg)
if wm and hm:
    print(f"{int(float(wm.group(1)))} {int(float(hm.group(1)))}")
    sys.exit(0)
# Last resort default
print("1200 800")
PY
)
WIDTH=$(echo "$DIMS" | awk '{print $1}')
HEIGHT=$(echo "$DIMS" | awk '{print $2}')
echo "Detected viewBox: ${WIDTH}x${HEIGHT}"
```

### Step 3 — Try Chrome headless (primary)

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

if [ -x "$CHROME" ]; then
  echo "Rendering via Chrome headless at ${SCALE}x..."
  "$CHROME" \
    --headless=new --disable-gpu \
    --screenshot="$OUTPUT" \
    --window-size="${WIDTH},${HEIGHT}" \
    --force-device-scale-factor="$SCALE" \
    --hide-scrollbars \
    --default-background-color=00000000 \
    "file://${SVG_ABS}" 2>/dev/null

  if [ -f "$OUTPUT" ]; then
    FINAL_W=$(sips -g pixelWidth "$OUTPUT" 2>/dev/null | tail -1 | awk '{print $2}')
    FINAL_H=$(sips -g pixelHeight "$OUTPUT" 2>/dev/null | tail -1 | awk '{print $2}')
    echo "✅ PNG written: ${FINAL_W}x${FINAL_H} → $OUTPUT"
    exit 0
  fi
fi
```

Notes on Chrome flags:
- `--headless=new` — uses the modern headless mode (better SVG rendering than legacy)
- `--force-device-scale-factor=2` — true 2× rendering, not post-hoc upscaling
- `--default-background-color=00000000` — transparent background (no white box around dark SVGs)
- `--hide-scrollbars` — prevents scrollbar slivers in the screenshot
- The `CVDisplayLinkCreateWithCGDisplay` warnings on macOS are harmless — file still writes correctly

### Step 4 — Fallback to rsvg-convert

```bash
if command -v rsvg-convert >/dev/null 2>&1; then
  echo "Chrome unavailable. Trying rsvg-convert..."
  TARGET_W=$((WIDTH * SCALE))
  rsvg-convert -w "$TARGET_W" "$SVG_ABS" -o "$OUTPUT"
  if [ -f "$OUTPUT" ]; then
    echo "✅ PNG written via rsvg-convert → $OUTPUT"
    exit 0
  fi
fi
```

If rsvg-convert is missing on macOS, suggest:
```bash
brew install librsvg
```

### Step 5 — Last-resort fallback to qlmanage

```bash
if command -v qlmanage >/dev/null 2>&1; then
  echo "⚠️  Falling back to qlmanage (forces square aspect, expect letterbox)..."
  TARGET_DIM=$((WIDTH * SCALE))
  if [ "$HEIGHT" -gt "$WIDTH" ]; then
    TARGET_DIM=$((HEIGHT * SCALE))
  fi
  qlmanage -t -s "$TARGET_DIM" -o "$(dirname "$OUTPUT")" "$SVG_ABS" >/dev/null 2>&1
  GENERATED="$(dirname "$OUTPUT")/$(basename "$SVG_ABS").png"
  if [ -f "$GENERATED" ]; then
    mv "$GENERATED" "$OUTPUT"
    echo "⚠️  PNG written via qlmanage (square canvas) → $OUTPUT"
    echo "    Aspect ratio NOT preserved. Install Chrome or librsvg for correct output."
    exit 0
  fi
fi

echo "ERROR: No SVG renderer available. Install Google Chrome or run: brew install librsvg"
exit 1
```

## Output Contract

After successful conversion, report:

```
## SVG → PNG conversion

**Source:**     <svg-path>
**Output:**     <png-path>
**Dimensions:** <W>x<H> (scale: <N>x, native viewBox: <ow>x<oh>)
**Method:**     Chrome headless | rsvg-convert | qlmanage
**Size:**       <bytes / KB>

Aspect ratio: ✅ preserved | ⚠️ forced square (qlmanage fallback)
```

## Common Pitfalls

- **Square output instead of correct aspect**: qlmanage was used. Install Chrome or rsvg.
- **White background on dark-themed SVG**: omit `--default-background-color=00000000` if you actually want white. Default is transparent for dark SVGs.
- **Blurry text / shapes**: scale was 1×. Re-run with `scale=2` or `3`.
- **Huge file size at 3×**: PNG at 3600px wide can hit several MB. Use 2× unless print-grade is needed.
- **Window-size mismatch with viewBox**: Chrome respects the SVG's intrinsic size when the file declares one — passing `--window-size` matching the viewBox prevents cropping or letterboxing.

## Batch Mode

For a directory of SVGs, ask the user if batch is wanted, then loop:

```bash
for svg in /path/to/dir/*.svg; do
  # Re-run Step 1–5 for each
done
```

Always report each conversion individually so the user sees per-file dimensions and method used.

## Cross-Platform Notes

- **macOS**: Chrome path `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`. `sips` available for verification.
- **Linux**: try `google-chrome`, `chromium`, or `chromium-browser` on PATH. `rsvg-convert` is usually `apt install librsvg2-bin`.
- **Windows / WSL**: use `chrome.exe` from `C:\Program Files\Google\Chrome\Application\` or recommend installing librsvg.

The skill should detect platform via `uname -s` and adjust the Chrome path lookup. macOS path is the default since this skill ships from a macOS-developed repo, but probe Linux paths if not found.
