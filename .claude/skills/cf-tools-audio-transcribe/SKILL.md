---
name: cf-tools-audio-transcribe
description: "Transcribe speech to text via OpenAI Whisper — outputs .txt + .srt subtitles. Trigger: /cf-tools-audio-transcribe"
trigger: /cf-tools-audio-transcribe
version: 1.0.0
---

# /cf-tools-audio-transcribe

Run speech-to-text on an audio (or video) file using OpenAI's open-source Whisper model. Emits a plain `.txt` transcript and an `.srt` subtitle file with timestamps.

## Prerequisite: install Whisper

Not installed by default. One-time setup:

```bash
pipx install openai-whisper
# verify
whisper --help
```

Whisper auto-downloads models (`~/.cache/whisper/`) on first use:

| Model    | Disk | RAM   | Speed   | Quality |
|----------|------|-------|---------|---------|
| `tiny`   | 75MB | ~1GB  | fastest | basic   |
| `base`   | 142MB| ~1GB  | fast    | decent  |
| `small`  | 466MB| ~2GB  | medium  | good    |
| `medium` | 1.5GB| ~5GB  | slow    | great   |
| `large`  | 3GB  | ~10GB | slowest | best    |

Default for this skill: `small` (good balance for English podcasts/lectures).

## Usage

```
/cf-tools-audio-transcribe input.mp3
/cf-tools-audio-transcribe input.mp3 --model medium --lang en
/cf-tools-audio-transcribe input.mp4 --output-dir transcripts/
/cf-tools-audio-transcribe input.mp3 --translate     # any language → English
```

Arguments:
1. `input` (required) — audio or video file
2. `--model <name>` (optional, default `small`) — tiny / base / small / medium / large
3. `--lang <code>` (optional) — ISO 639-1, e.g. `en`, `es`, `fr` (auto-detect if omitted)
4. `--output-dir <path>` (optional, default same dir as input)
5. `--translate` (optional flag) — output English regardless of source language

## What You Must Do When Invoked

### Step 1 — Verify whisper installed

```bash
if ! command -v whisper >/dev/null 2>&1; then
  echo "ERROR: whisper not installed."
  echo "Run: pipx install openai-whisper"
  exit 1
fi
```

### Step 2 — Parse args

```bash
INPUT="$1"; shift
MODEL="small"; LANG=""; OUTDIR=""; TASK="transcribe"
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --lang) LANG="$2"; shift 2 ;;
    --output-dir) OUTDIR="$2"; shift 2 ;;
    --translate) TASK="translate"; shift ;;
    *) shift ;;
  esac
done
[ -f "$INPUT" ] || { echo "ERROR: input not found"; exit 1; }
OUTDIR="${OUTDIR:-$(dirname "$INPUT")}"
mkdir -p "$OUTDIR"
```

### Step 3 — Run whisper

```bash
LANG_ARG=""
[ -n "$LANG" ] && LANG_ARG="--language $LANG"

whisper "$INPUT" \
  --model "$MODEL" \
  --task "$TASK" \
  --output_dir "$OUTDIR" \
  --output_format txt --output_format srt \
  $LANG_ARG \
  --verbose False
```

Whisper writes `<basename>.txt` and `<basename>.srt` into `$OUTDIR`.

### Step 4 — Verify

```bash
STEM=$(basename "${INPUT%.*}")
TXT="${OUTDIR}/${STEM}.txt"
SRT="${OUTDIR}/${STEM}.srt"
[ -s "$TXT" ] && [ -s "$SRT" ] || { echo "ERROR: whisper produced empty output"; exit 1; }
LINES=$(wc -l < "$TXT")
CUES=$(grep -c "^[0-9]\+$" "$SRT")
```

## Output Contract

```
## Audio transcribe

**Source:**     <input>
**Model:**      <model>
**Language:**   <detected or specified>
**Task:**       transcribe | translate (→ English)
**Outputs:**
  - <output-dir>/<stem>.txt   (<N> lines)
  - <output-dir>/<stem>.srt   (<M> subtitle cues)
**Duration:**   <s>s (source)
```

## .srt Format Sample

```
1
00:00:00,000 --> 00:00:04,500
Welcome to the episode.

2
00:00:04,500 --> 00:00:09,200
Today we're talking about loudness normalization.
```

Use the `.srt` directly with video players, YouTube uploads, or convert to `.vtt` for the web (`ffmpeg -i in.srt out.vtt`).

## Gotchas

- **First run downloads model** (75 MB – 3 GB depending on size). Allow 2-30 minutes on slow connections.
- **No GPU = slow**: large model on CPU takes ~real-time. Use `tiny` or `base` on laptops without CUDA/MPS.
- **Apple Silicon**: whisper auto-uses MPS in recent versions. If it falls back to CPU, install `whisper-mlx` or use `--device mps`.
- **Bad transcripts on music**: Whisper is trained on speech; lyrics with backing music produce hallucinations. Pre-isolate vocals with `demucs` (see `cf-tools-audio-denoise`) for better results.
- **Long files**: a 2-hour file with `large` on CPU can take 8+ hours. Split first with `cf-tools-audio-trim`.
- **Hallucinated subtitles during silence**: the `--condition_on_previous_text False` flag reduces this; consider adding it for noisy / silent-heavy sources.

## Cross-Platform Notes

- **macOS**: `pipx install openai-whisper`. Requires ffmpeg on PATH (already a prerequisite of this skill family).
- **Linux**: same. For NVIDIA GPU, install via `pip install torch --index-url https://download.pytorch.org/whl/cu121` first inside the pipx env.
- **Windows**: `pipx install openai-whisper`. ffmpeg via `winget install ffmpeg`.
