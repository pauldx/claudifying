---
name: cf-tools-image-diff
description: "Pixel-level image diff with absolute-error count + SSIM perceptual metric and visual diff PNG. Trigger: /cf-tools-image-diff"
trigger: /cf-tools-image-diff
version: 1.0.0
---

# /cf-tools-image-diff

Compare two images and produce:
1. **AE** — absolute number of differing pixels.
2. **SSIM** — structural similarity (0=different, 1=identical), perceptual metric.
3. **Visual diff PNG** — pixels that differ highlighted in red.

Useful for visual regression testing, screenshot comparison, and asset deduplication.

## Usage

```
/cf-tools-image-diff <image-a> <image-b>
/cf-tools-image-diff <image-a> <image-b> --output diff.png
/cf-tools-image-diff <image-a> <image-b> --fuzz 5%      # ignore tiny color shifts
/cf-tools-image-diff <image-a> <image-b> --threshold 0.95   # SSIM gate for "same"
```

Flags:
- `--output PATH` — visual diff PNG (default `<a-stem>-vs-<b-stem>-diff.png`)
- `--fuzz N%` — color tolerance (default `0%` = exact match required)
- `--threshold N` — SSIM threshold for pass/fail return code (0.0-1.0; default off)

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
IMG_A="$1"; shift
IMG_B="$1"; shift
[ -f "$IMG_A" ] || { echo "ERROR: not found: $IMG_A"; exit 1; }
[ -f "$IMG_B" ] || { echo "ERROR: not found: $IMG_B"; exit 1; }

STEM_A=$(basename "${IMG_A%.*}")
STEM_B=$(basename "${IMG_B%.*}")
OUTPUT="${STEM_A}-vs-${STEM_B}-diff.png"
FUZZ="0%"; THRESHOLD=""

while [ $# -gt 0 ]; do
  case "$1" in
    --output)    OUTPUT="$2"; shift 2;;
    --fuzz)      FUZZ="$2"; shift 2;;
    --threshold) THRESHOLD="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done
```

### Step 2 — Compare dimensions (fail fast)

```bash
WA=$(magick identify -format "%w" "$IMG_A")
HA=$(magick identify -format "%h" "$IMG_A")
WB=$(magick identify -format "%w" "$IMG_B")
HB=$(magick identify -format "%h" "$IMG_B")

if [ "$WA" != "$WB" ] || [ "$HA" != "$HB" ]; then
  echo "WARN: dimensions differ — A=${WA}x${HA}, B=${WB}x${HB}"
  echo "Resizing B to A's dimensions for comparison..."
  magick "$IMG_B" -resize "${WA}x${HA}!" /tmp/_diff_b.png
  IMG_B="/tmp/_diff_b.png"
fi
```

### Step 3 — Run AE and SSIM metrics

```bash
# AE returns count of differing pixels. Note: returns exit 1 when images differ.
AE_OUTPUT=$(magick compare -metric AE -fuzz "$FUZZ" "$IMG_A" "$IMG_B" "$OUTPUT" 2>&1 || true)
AE_COUNT=$(echo "$AE_OUTPUT" | grep -oE '^[0-9.]+' | head -1)

# SSIM gives perceptual similarity (0-1)
SSIM_OUTPUT=$(magick compare -metric SSIM "$IMG_A" "$IMG_B" /dev/null 2>&1 || true)
SSIM_VAL=$(echo "$SSIM_OUTPUT" | grep -oE '[0-9.]+' | head -1)

TOTAL_PIXELS=$((WA * HA))
PCT_DIFF=$(awk "BEGIN { printf \"%.4f\", ($AE_COUNT / $TOTAL_PIXELS) * 100 }")
```

### Step 4 — Report

```bash
echo ""
echo "## Image diff"
echo ""
echo "**A:**           $IMG_A  (${WA}x${HA})"
echo "**B:**           $IMG_B  (${WB}x${HB})"
echo "**Diff pixels:** $AE_COUNT / $TOTAL_PIXELS  (${PCT_DIFF}%)"
echo "**SSIM:**        $SSIM_VAL  (1.0 = identical)"
echo "**Visual diff:** $OUTPUT"
echo ""

if [ -n "$THRESHOLD" ]; then
  PASS=$(awk "BEGIN { print ($SSIM_VAL >= $THRESHOLD) ? 1 : 0 }")
  if [ "$PASS" = "1" ]; then
    echo "PASS: SSIM $SSIM_VAL >= threshold $THRESHOLD"
    exit 0
  else
    echo "FAIL: SSIM $SSIM_VAL < threshold $THRESHOLD"
    exit 1
  fi
fi
```

## Output Contract

```
## Image diff

**A:**           <path>  (<WxH>)
**B:**           <path>  (<WxH>)
**Diff pixels:** <count> / <total>  (<%>)
**SSIM:**        <0.0-1.0>
**Visual diff:** <path>  (red pixels = differences)
**Threshold:**   PASS | FAIL @ <N>   (if --threshold given)
```

## Verified Test

```bash
magick sample.png -modulate 110 sample_b.png
magick compare -metric AE sample.png sample_b.png diff_ae.png  → 16709 (0.254959)
magick compare -metric SSIM sample.png sample_b.png /dev/null  → 4425.9 (0.067535)
```
(magick compare returns exit 1 when images differ — script handles via `|| true`.)

## Gotchas

- **`magick compare` returns exit 1 if images differ** — not an error; we use `|| true` and parse stdout.
- **Dimensions must match** — script resizes B to A's size. For pixel-perfect testing, both inputs MUST be identical dimensions; resize is a courtesy.
- **AE = 0 doesn't mean visually identical** — could be color profile differences invisible to the eye. SSIM catches perceptual identity better.
- **SSIM output format** varies by IM version: some emit `0.9234`, others `0.9234 (0.9234)`. The grep extracts the first numeric.
- **`-fuzz 5%`** ignores small color shifts (anti-aliasing, JPEG noise). Use for flaky screenshot tests.
- **Color profiles affect comparison** — if one image has ICC profile and the other doesn't, AE may be huge. Strip both first via cf-tools-image-strip-metadata for fair comparison.
- **`/dev/null` as output** for SSIM works on Unix; on Windows pass a temp filename you delete after.

## Cross-Platform Notes

- **macOS / Linux / Windows**: `magick compare` ships with ImageMagick.
- For higher-fidelity perceptual diffs use `dssim` (Rust) — outside this toolchain but worth knowing for visual regression test suites.
