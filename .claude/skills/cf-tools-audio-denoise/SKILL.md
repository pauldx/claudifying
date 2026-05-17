---
name: cf-tools-audio-denoise
description: "Reduce noise (hiss, hum, room tone) via ffmpeg arnndn filter — RNNoise model based. Falls back to demucs for source separation. Trigger: /cf-tools-audio-denoise"
trigger: /cf-tools-audio-denoise
version: 1.0.0
---

# /cf-tools-audio-denoise

Two-tier denoise: lightweight RNNoise (built into ffmpeg) for speech / podcasts, demucs (Python, optional) for true source separation (extract vocals from music).

## Tier 1 — RNNoise (default, no extra install)

Uses ffmpeg's `arnndn` filter with a pretrained RNNoise model. Built for speech band; reduces hiss, fan noise, fluorescent buzz.

You need a model file (`.rnnn`). The most-used community model:

```bash
# Download once
mkdir -p ~/.cache/rnnoise-models
curl -L -o ~/.cache/rnnoise-models/sh.rnnn \
  https://github.com/GregorR/rnnoise-models/raw/master/somnolent-hogwash-2018-09-01/sh.rnnn
```

## Tier 2 — Demucs (optional, for music / source separation)

Stronger but heavier. Splits a track into vocals/drums/bass/other stems.

```bash
pipx install demucs
demucs --help
```

## Usage

```
/cf-tools-audio-denoise input.mp3 output.mp3                             # RNNoise default
/cf-tools-audio-denoise input.mp3 output.mp3 --model ~/models/cb.rnnn    # custom model
/cf-tools-audio-denoise input.mp3 output.mp3 --aggressive                # RNNoise + highpass + lowpass
/cf-tools-audio-denoise input.mp3 --demucs                                # vocal isolation via demucs
```

Arguments:
1. `input` (required)
2. `output` (required for RNNoise; omitted for `--demucs` which writes a `separated/` dir)
3. `--model <path>` (optional, default `~/.cache/rnnoise-models/sh.rnnn`)
4. `--aggressive` (optional flag) — adds highpass 80 Hz + lowpass 12 kHz to the chain
5. `--demucs` (optional flag) — switch to demucs source separation mode

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; OUTPUT="$2"; shift 2
MODEL="$HOME/.cache/rnnoise-models/sh.rnnn"
AGGRESSIVE=0; USE_DEMUCS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --aggressive) AGGRESSIVE=1; shift ;;
    --demucs) USE_DEMUCS=1; shift ;;
    *) shift ;;
  esac
done
[ -f "$INPUT" ] || { echo "ERROR: input not found"; exit 1; }
```

### Step 2a — Demucs path

```bash
if [ "$USE_DEMUCS" -eq 1 ]; then
  if ! command -v demucs >/dev/null 2>&1; then
    echo "ERROR: demucs not installed."
    echo "Run: pipx install demucs"
    exit 1
  fi
  demucs -o ./separated "$INPUT"
  # outputs: ./separated/htdemucs/<stem>/{vocals,drums,bass,other}.wav
  exit 0
fi
```

### Step 2b — RNNoise path

```bash
if [ ! -f "$MODEL" ]; then
  echo "ERROR: model not found: $MODEL"
  echo "Download: curl -L -o $MODEL https://github.com/GregorR/rnnoise-models/raw/master/somnolent-hogwash-2018-09-01/sh.rnnn"
  exit 1
fi
```

### Step 3 — Build filter chain

```bash
FILTERS=("arnndn=m=${MODEL}")
if [ "$AGGRESSIVE" -eq 1 ]; then
  FILTERS+=("highpass=f=80" "lowpass=f=12000")
fi
FILTER_STR=$(IFS=,; echo "${FILTERS[*]}")
```

### Step 4 — Pick codec & apply

```bash
EXT="${OUTPUT##*.}"
case "$EXT" in
  mp3) CODEC="libmp3lame -b:a 192k" ;;
  aac|m4a) CODEC="aac -b:a 192k" ;;
  wav) CODEC="pcm_s16le" ;;
  flac) CODEC="flac" ;;
  opus) CODEC="libopus -b:a 96k" ;;
  *) CODEC="libmp3lame -b:a 192k" ;;
esac

# RNNoise requires 48 kHz mono/stereo input internally; ffmpeg auto-resamples
ffmpeg -y -i "$INPUT" -af "$FILTER_STR" -c:a $CODEC "$OUTPUT"
```

### Step 5 — Verify

```bash
ffprobe -v error -show_entries format=duration,size -of default=noprint_wrappers=1 "$OUTPUT"
```

A/B by ear; no objective number is meaningful without ground-truth clean signal.

## Output Contract (RNNoise mode)

```
## Audio denoise (RNNoise)

**Source:**     <input>
**Output:**     <output>
**Model:**      <model_path>
**Aggressive:** yes | no
**Duration:**   <s>s
**Size:**       <KB>
```

## Output Contract (Demucs mode)

```
## Audio denoise (demucs source separation)

**Source:**       <input>
**Output dir:**   ./separated/htdemucs/<stem>/
**Stems:**        vocals.wav, drums.wav, bass.wav, other.wav
**Duration:**     <s>s (each stem)
```

## Gotchas

- **RNNoise on music**: trained for speech. Applied to music it scrubs high frequencies and reverb. Use demucs for music.
- **Aggressive filter eats consonants**: highpass at 80 Hz + lowpass at 12 kHz removes "S" and "T" detail. Acceptable for podcasts, bad for ASMR.
- **Model choice matters**: `cb.rnnn` (conversational broadband) better for telephone-band, `sh.rnnn` (somnolent hogwash) better for studio. Both at the same GitHub repo.
- **Demucs is GPU-hungry**: ~10× real-time on CPU, 0.5× on GPU. Use `--device cpu` to force off-GPU on machines with broken CUDA.
- **Demucs outputs at 44.1 kHz wav**: re-convert with `cf-tools-audio-convert` if you need mp3.
- **No external model = filter silently passes audio through**: ffmpeg doesn't always error on missing model; verify with A/B comparison.

## Cross-Platform Notes

- **macOS**: ffmpeg includes arnndn since 4.1. Demucs via pipx.
- **Linux**: same. GPU demucs needs CUDA torch.
- **Windows**: gyan.dev / BtbN ffmpeg builds include arnndn. Demucs via pipx + Python 3.10.
