---
name: cf-tools-web-og-image-render
description: "Render a 1200x630 Open-Graph PNG with title and subtitle text via ImageMagick. Trigger: /cf-tools-web-og-image-render"
trigger: /cf-tools-web-og-image-render
version: 1.0.0
---

# /cf-tools-web-og-image-render

Render a 1200×630 Open-Graph / Twitter-card image with a centered title plus
optional subtitle. Uses ImageMagick (`magick`). Defaults to a dark slate
background (`#0f172a`) with white text — looks good across Twitter, LinkedIn,
Slack previews.

## Usage

```
/cf-tools-web-og-image-render "My Post Title"
/cf-tools-web-og-image-render "My Post Title" "Subtitle line below"
/cf-tools-web-og-image-render "My Post Title" "Subtitle" ./og.png
/cf-tools-web-og-image-render "My Post Title" "Subtitle" ./og.png "#1e293b" "#f59e0b"
```

Arguments:
1. `title` (required) — main heading text
2. `subtitle` (optional, default empty) — smaller line below title
3. `output` (optional, default `./og-image.png`)
4. `bg` (optional, default `#0f172a`) — background hex
5. `fg` (optional, default `#ffffff`) — text color hex

## What You Must Do When Invoked

### Step 1 — Verify magick installed

```bash
if ! command -v magick >/dev/null 2>&1; then
  echo "ERROR: ImageMagick not installed."
  echo "  macOS:  brew install imagemagick"
  echo "  Linux:  sudo apt-get install -y imagemagick"
  exit 1
fi
```

### Step 2 — Detect a usable font

ImageMagick on recent macOS often can't find fonts by short name. Detect a
ttf file directly:

```bash
FONT=""
for f in \
  /System/Library/Fonts/Supplemental/Arial.ttf \
  /System/Library/Fonts/Helvetica.ttc \
  /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf \
  /usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf \
  C:/Windows/Fonts/arial.ttf
do
  [ -f "$f" ] && FONT="$f" && break
done
[ -z "$FONT" ] && { echo "ERROR: no usable TTF font found"; exit 1; }
```

### Step 3 — Render

```bash
TITLE="$1"
SUB="${2:-}"
OUT="${3:-./og-image.png}"
BG="${4:-#0f172a}"
FG="${5:-#ffffff}"

if [ -n "$SUB" ]; then
  # Two-line layout: title at center-top, subtitle below
  magick -size 1200x630 "xc:${BG}" \
    -font "$FONT" -fill "$FG" -gravity center \
    -pointsize 84 -annotate +0-60 "$TITLE" \
    -pointsize 36 -annotate +0+80 "$SUB" \
    "$OUT"
else
  magick -size 1200x630 "xc:${BG}" \
    -font "$FONT" -fill "$FG" -gravity center \
    -pointsize 96 -annotate +0+0 "$TITLE" \
    "$OUT"
fi
```

### Step 4 — Verify dimensions are exactly 1200×630

```bash
DIM=$(magick identify -format "%wx%h" "$OUT")
if [ "$DIM" != "1200x630" ]; then
  echo "ERROR: output dimensions $DIM != 1200x630"
  exit 1
fi
SIZE=$(wc -c < "$OUT" | tr -d ' ')
echo "✅ OG image: $DIM, ${SIZE} bytes → $OUT"
```

## Output Contract

```
## Open-Graph image rendered

**Title:**       "<title>"
**Subtitle:**    "<subtitle>" | (none)
**Output:**      <path>
**Dimensions:**  1200x630 (verified)
**Background:**  <hex>
**Foreground:**  <hex>
**Font:**        <path to ttf>
**Bytes:**       <size>
```

## Gotchas

- **`unable to read font 'Arial'` / `'Helvetica'`** — modern ImageMagick on
  macOS no longer ships its own fonts; you must pass an absolute TTF path.
  Step 2 above handles this.
- **Long titles overflow the canvas** — title over ~50 chars at 96pt will run
  off the edges. Wrap with `\n` literal in the string, or lower pointsize
  manually.
- **Emoji renders as boxes** — `Arial.ttf` doesn't have emoji glyphs. Use
  `/System/Library/Fonts/Apple Color Emoji.ttc` and reduce pointsize, or
  pre-strip emoji before rendering.
- **Image ends up 1199×629 or similar** — old ImageMagick `convert` syntax was
  off-by-one in some versions. The `magick` v7 command in Step 3 is exact.
- **Non-Latin scripts (CJK, Arabic, Devanagari)** — Arial doesn't have those
  glyphs. Use `Arial Unicode.ttf` (macOS Supplemental) or `NotoSans-*.ttf`.
- **Right-to-left text reverses oddly** — magick's `-annotate` doesn't BiDi.
  For Arabic/Hebrew use `-draw 'text 0,0'` with pango-rendered SVG instead.

## Cross-Platform Notes

- **macOS**: ImageMagick via `brew install imagemagick`. Fonts in
  `/System/Library/Fonts/`.
- **Linux**: `apt-get install imagemagick fonts-liberation`. DejaVu fonts
  pre-installed on most distros.
- **Windows**: Install from imagemagick.org. Arial at `C:/Windows/Fonts/arial.ttf`.
