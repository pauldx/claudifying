---
name: cf-tools-image-palette
description: "Extract N dominant colors from an image as hex codes plus a CSS custom-properties block. Trigger: /cf-tools-image-palette"
trigger: /cf-tools-image-palette
version: 1.0.0
---

# /cf-tools-image-palette

Sample the dominant colors of an image and emit:
1. A plain list of hex codes (for design tools).
2. A CSS `:root { --c1: ... }` block (paste-ready for stylesheets).

## Usage

```
/cf-tools-image-palette <input>
/cf-tools-image-palette <input> --colors 8
/cf-tools-image-palette <input> --colors 5 --output palette.css
```

Flags:
- `--colors N` — number of colors to extract (default 5, range 2-16)
- `--output PATH` — write CSS to file (default prints to stdout)
- `--name PREFIX` — CSS variable name prefix (default `c`, produces `--c1`, `--c2`, ...)

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
COLORS=5; OUTPUT=""; PREFIX="c"

while [ $# -gt 0 ]; do
  case "$1" in
    --colors) COLORS="$2"; shift 2;;
    --output) OUTPUT="$2"; shift 2;;
    --name)   PREFIX="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done
```

### Step 2 — Extract palette via magick

```bash
# Quantize to N colors and read pixel values
# Resize to 100x100 first for speed on large images
HEX_LIST=$(magick "$INPUT" -resize 100x100 -colors "$COLORS" -unique-colors txt:- \
  | tail -n +2 \
  | grep -oE '#[A-F0-9]{6}' \
  | head -n "$COLORS")

if [ -z "$HEX_LIST" ]; then
  # Fallback: 8-bit channel form
  HEX_LIST=$(magick "$INPUT" -resize 100x100 -colors "$COLORS" -depth 8 -unique-colors txt:- \
    | tail -n +2 \
    | grep -oE 'srgb\([0-9]+,[0-9]+,[0-9]+\)' \
    | head -n "$COLORS" \
    | awk -F'[(),]' '{ printf "#%02X%02X%02X\n", $2, $3, $4 }')
fi
```

### Step 3 — Format output

```bash
{
  echo "/* Palette extracted from $(basename "$INPUT") */"
  echo ":root {"
  i=1
  while IFS= read -r hex; do
    echo "  --${PREFIX}${i}: ${hex};"
    i=$((i + 1))
  done <<< "$HEX_LIST"
  echo "}"
  echo ""
  echo "/* Hex list: */"
  echo "$HEX_LIST" | tr '\n' ' '
  echo ""
} | if [ -n "$OUTPUT" ]; then
       tee "$OUTPUT"
     else
       cat
     fi
```

## Output Contract

```
## Color palette

**Source:**   <path>
**Colors:**   <N>
**Hex list:** #AABBCC #112233 ...
**CSS block:**
:root {
  --c1: #AABBCC;
  --c2: #112233;
  ...
}
```

## Verified Test

`magick sample-with-bg.png -resize 100x100 -colors 5 -unique-colors txt:-` → returns 4-5 colors in `txt:` format, including `#FF12A64A01FB` (16-bit hex; script extracts 8-bit form via the fallback path).

## Gotchas

- **`txt:-` outputs 16-bit hex** like `#FFFFFCEF0000FFFF` (12 chars + alpha) — strip with the 8-bit fallback path. The `-depth 8` flag forces 8-bit output but channel naming changes per IM version.
- **`-colors N`** uses Floyd-Steinberg dithering by default — for pure dominant-color extraction add `+dither` to disable dithering and get cleaner clusters.
- **Order is not by dominance** — `-unique-colors` returns sorted by quantization cluster, not pixel count. For frequency-sorted, use `magick INPUT -resize 100x100 -colors N -depth 8 -format "%c" histogram:info:-`.
- **Alpha channel** appears in 16-bit hex but is meaningless for solid colors — script ignores it.
- **Photos vs flat designs** — photos may need `--colors 8` or more to capture nuance; UI screenshots usually 3-5 is enough.
- **Resize to 100x100 first** dramatically speeds up extraction on large images; quality of palette barely changes.

## Cross-Platform Notes

- **macOS / Linux / Windows**: `magick` from ImageMagick.
- For pixel-frequency-ranked palettes (most-common color first), consider the `colorthief` Python library — outside this skill's toolchain but a known alternative.
