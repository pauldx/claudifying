---
name: cf-tools-image-bg-remove
description: "Remove image background using rembg (U^2-Net). Outputs PNG with transparent alpha. Trigger: /cf-tools-image-bg-remove"
trigger: /cf-tools-image-bg-remove
version: 1.0.0
---

# /cf-tools-image-bg-remove

ML-based background removal using **rembg** (built on U^2-Net / IS-Net / SAM models). Produces a PNG with transparent alpha for product shots, portraits, and asset extraction.

## Prerequisites — Install rembg

`rembg` is **not** installed by default. Install via:

```bash
# Recommended: isolated install via pipx
pipx install "rembg[cli]"

# Or via pip in a venv
python3 -m venv ~/.local/venvs/rembg
source ~/.local/venvs/rembg/bin/activate
pip install "rembg[cli]"

# Verify
rembg --version
```

First run downloads the model (~170MB for default `u2net`) to `~/.u2net/`.

## Usage

```
/cf-tools-image-bg-remove <input>
/cf-tools-image-bg-remove <input> --model isnet-general-use
/cf-tools-image-bg-remove <input> --output cutout.png
/cf-tools-image-bg-remove <input> --alpha-matting        # finer hair/edge detail
```

Flags:
- `--model NAME` — model to use:
  - `u2net` (default, 170MB, general purpose)
  - `u2netp` (4MB, lightweight)
  - `u2net_human_seg` (best for people)
  - `isnet-general-use` (best general-purpose, newer)
  - `isnet-anime` (anime/illustration)
  - `sam` (Segment Anything, heaviest)
- `--alpha-matting` — refine edges (slower, better for hair/fur)
- `--output PATH` — default `<stem>-nobg.png`

## What You Must Do When Invoked

### Step 1 — Check rembg presence; exit early if missing

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
STEM="${INPUT%.*}"
OUTPUT="${STEM}-nobg.png"
MODEL="u2net"; ALPHA=0

while [ $# -gt 0 ]; do
  case "$1" in
    --model)         MODEL="$2"; shift 2;;
    --alpha-matting) ALPHA=1; shift;;
    --output)        OUTPUT="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done

if ! command -v rembg >/dev/null 2>&1; then
  cat <<'EOF'
ERROR: rembg not installed.

Install with:
  pipx install "rembg[cli]"

Or in a venv:
  python3 -m venv ~/.local/venvs/rembg
  source ~/.local/venvs/rembg/bin/activate
  pip install "rembg[cli]"

First run downloads the model (~170MB) to ~/.u2net/.
EOF
  exit 2
fi
```

### Step 2 — Run rembg

```bash
ARGS=(i -m "$MODEL")
[ "$ALPHA" = "1" ] && ARGS+=(-a)

rembg "${ARGS[@]}" "$INPUT" "$OUTPUT"
```

### Step 3 — Verify alpha channel present

```bash
[ -f "$OUTPUT" ] || { echo "ERROR: rembg produced no output"; exit 1; }
HAS_ALPHA=$(magick identify -format "%[channels]" "$OUTPUT" | grep -c "a")
W=$(magick identify -format "%w" "$OUTPUT")
H=$(magick identify -format "%h" "$OUTPUT")
echo "Output: $OUTPUT  (${W}x${H}, alpha: $([ "$HAS_ALPHA" = "1" ] && echo yes || echo no))"
```

## Output Contract

```
## Background removed

**Input:**     <path>
**Output:**    <path>  (PNG with alpha)
**Model:**     u2net | isnet-general-use | etc
**Alpha matting:** on | off
**Dimensions:** <W>x<H>
**File size:**  <KB>
```

## Verification status

NOT live-tested in this skill batch — `rembg` was not installed in the test environment. The CLI invocation `rembg i -m u2net input.png output.png` is documented in [rembg's official README](https://github.com/danielgatis/rembg) and is the upstream-supported call shape.

## Gotchas

- **First run downloads model** — `u2net` is 170MB. On metered connections, pre-download by running once with a sample image.
- **`rembg` exits 2 here** — to signal "missing binary, install required" cleanly to the calling agent. Distinct from exit 1 (runtime error).
- **`sam` model needs huge VRAM** (~6GB) — don't use on machines without dedicated GPU.
- **`-a` (alpha matting)** triples runtime but gives much cleaner hair/fur edges. Use for portraits, skip for product shots.
- **Output is always PNG** with alpha. If you need JPG with a solid background, post-process: `magick out.png -background white -alpha remove -alpha off out.jpg`.
- **GPU acceleration** — install `onnxruntime-gpu` instead of CPU build for ~10× speedup on NVIDIA hardware.
- **`u2netp` (4MB)** is dramatically lower quality than `u2net` (170MB) — only use on storage-constrained systems.

## Cross-Platform Notes

- **macOS**: `pipx install "rembg[cli]"`. M-series Macs use CPU build (no MPS support in onnxruntime as of writing).
- **Linux**: same install; for GPU swap to `onnxruntime-gpu`.
- **Windows**: pip install works; rembg also publishes Docker image for clean install.

## Alternatives

- `BackgroundRemoval.js` (browser-side, free)
- `remove.bg` API (paid, very high quality)
- Apple's Vision framework on macOS (no install, decent quality) — accessible via `python3 -c "import Vision"` with `pyobjc`
