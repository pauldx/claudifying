---
name: cf-tools-image-upscale
description: "AI-based image upscaling 2x/4x using Real-ESRGAN with model selection. Trigger: /cf-tools-image-upscale"
trigger: /cf-tools-image-upscale
version: 1.0.0
---

# /cf-tools-image-upscale

ML-based super-resolution using **Real-ESRGAN** (Enhanced SRGAN). Far better than bicubic resize — recovers detail, sharpens edges, and avoids the smeared look of traditional interpolation.

## Prerequisites — Install realesrgan

`realesrgan` is **not** installed by default. Install via:

```bash
# Option A: pre-built binary (recommended, no Python)
# macOS:
brew install realesrgan-ncnn-vulkan
# or download from https://github.com/xinntao/Real-ESRGAN/releases

# Linux: download the binary release tarball:
wget https://github.com/xinntao/Real-ESRGAN/releases/latest/download/realesrgan-ncnn-vulkan-<ver>-ubuntu.zip
unzip realesrgan-ncnn-vulkan-*-ubuntu.zip -d ~/.local/bin/

# Option B: Python package
pipx install realesrgan
# (heavier — installs PyTorch and CUDA deps)

# Verify
realesrgan-ncnn-vulkan -h
```

The pre-built binary ships with models in a `models/` folder next to the binary — no separate download needed.

## Usage

```
/cf-tools-image-upscale <input>
/cf-tools-image-upscale <input> --scale 4
/cf-tools-image-upscale <input> --model realesrgan-x4plus-anime
/cf-tools-image-upscale <input> --output big.png
```

Flags:
- `--scale N` — 2, 3, or 4 (default 2)
- `--model NAME` — model file (without extension):
  - `realesrgan-x4plus` (default, photo-realistic)
  - `realesrgan-x4plus-anime` (anime/illustration)
  - `realesr-animevideov3` (animated video frames)
  - `realesrnet-x4plus` (less aggressive, more faithful)
- `--output PATH` — default `<stem>-up<scale>x.<ext>`
- `--format png|jpg|webp` — output format (default same as input)

## What You Must Do When Invoked

### Step 1 — Check binary presence

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
STEM="${INPUT%.*}"
EXT="${INPUT##*.}"
SCALE=2; MODEL="realesrgan-x4plus"; OUTPUT=""; FORMAT="$EXT"

while [ $# -gt 0 ]; do
  case "$1" in
    --scale)  SCALE="$2"; shift 2;;
    --model)  MODEL="$2"; shift 2;;
    --output) OUTPUT="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done

[ -z "$OUTPUT" ] && OUTPUT="${STEM}-up${SCALE}x.${FORMAT}"

# Locate binary
BIN=""
for cand in realesrgan-ncnn-vulkan realesrgan realesrgan-ncnn; do
  if command -v "$cand" >/dev/null 2>&1; then
    BIN="$cand"
    break
  fi
done

if [ -z "$BIN" ]; then
  cat <<'EOF'
ERROR: realesrgan not installed.

Install with (macOS):
  brew install realesrgan-ncnn-vulkan

Or download pre-built binary from:
  https://github.com/xinntao/Real-ESRGAN/releases

Or via Python:
  pipx install realesrgan
EOF
  exit 2
fi
```

### Step 2 — Run upscaler

```bash
# realesrgan-ncnn-vulkan CLI:
#   -i <input> -o <output> -n <model> -s <scale> -f <format>
"$BIN" -i "$INPUT" -o "$OUTPUT" -n "$MODEL" -s "$SCALE" -f "${FORMAT}" 2>&1 | tail -5
```

### Step 3 — Verify

```bash
[ -f "$OUTPUT" ] || { echo "ERROR: upscaler produced no output"; exit 1; }
SRC_W=$(magick identify -format "%w" "$INPUT")
SRC_H=$(magick identify -format "%h" "$INPUT")
DST_W=$(magick identify -format "%w" "$OUTPUT")
DST_H=$(magick identify -format "%h" "$OUTPUT")
echo "Upscaled: ${SRC_W}x${SRC_H} → ${DST_W}x${DST_H} (scale=${SCALE}x) → $OUTPUT"
```

## Output Contract

```
## Image upscale

**Input:**    <path>  (<W>x<H>)
**Output:**   <path>  (<W*scale>x<H*scale>)
**Scale:**    2x | 3x | 4x
**Model:**    realesrgan-x4plus | -anime | -animevideov3 | realesrnet-x4plus
**Backend:**  ncnn-vulkan (GPU) | python (CPU/CUDA)
```

## Verification status

NOT live-tested in this skill batch — `realesrgan-ncnn-vulkan` was not installed in the test environment. CLI shape matches upstream [Real-ESRGAN-ncnn-vulkan docs](https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan).

## Gotchas

- **Two flavors of realesrgan**: `ncnn-vulkan` (C++, GPU via Vulkan, ships pre-built) vs Python (`pip install realesrgan`, needs PyTorch). The pre-built binary is dramatically easier to install.
- **Scale parameter** for x4plus model: the model itself is 4× but `-s 2` gives proportional output by downsampling the 4× result.
- **Anime model on photos** produces oily, over-smoothed results — pick the right model.
- **Memory consumption** scales with input size — for 4K input + 4× scale you need ~8GB VRAM. Tile mode in the binary handles this but slows down.
- **Output format conversion** — `-f` flag in ncnn-vulkan supports jpg/png/webp. Don't pipe through external converter if avoidable.
- **Texture banding** can appear on solid color regions with x4plus model — try `realesrnet-x4plus` for cleaner gradients.
- **GPU required for reasonable speed** — CPU mode is 50-100× slower than GPU. macOS Apple Silicon: ncnn-vulkan uses Metal via MoltenVK, works fine.
- **Don't upscale already-upscaled images** — artifacts compound.

## Cross-Platform Notes

- **macOS**: `brew install realesrgan-ncnn-vulkan`. Apple Silicon supported via MoltenVK.
- **Linux**: pre-built binary from GitHub releases, ~30MB.
- **Windows**: pre-built `.exe` from GitHub releases.

## Alternatives

- `waifu2x-ncnn-vulkan` (similar, optimized for anime/illustrations)
- Adobe Super Resolution (Photoshop / Lightroom, paid)
- `topaz-gigapixel-ai` (commercial, market-leader quality)
- macOS Image Playground / Apple Intelligence (built-in, limited control)
