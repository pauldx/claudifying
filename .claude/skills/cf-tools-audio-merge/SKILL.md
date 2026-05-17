---
name: cf-tools-audio-merge
description: "Concatenate multiple audio files into one — fast lossless path for same-codec, filter path for mixed. Trigger: /cf-tools-audio-merge"
trigger: /cf-tools-audio-merge
version: 1.0.0
---

# /cf-tools-audio-merge

Join two or more audio files end-to-end. Auto-detects whether all inputs share the same codec/sample-rate (uses fast concat demuxer) or whether re-encoding is required (uses the concat filter).

## Usage

```
/cf-tools-audio-merge output.mp3 part1.mp3 part2.mp3 part3.mp3
/cf-tools-audio-merge output.wav clip-a.wav clip-b.wav
/cf-tools-audio-merge merged.mp3 --list playlist.txt
```

Arguments:
1. `output` (required) — final merged path
2. Two or more input paths OR `--list <txtfile>` containing one path per line (the txt file uses the `file 'path'` format expected by ffmpeg concat demuxer)

## What You Must Do When Invoked

### Step 1 — Collect inputs

```bash
OUTPUT="$1"; shift
INPUTS=()
LIST_FILE=""
if [ "$1" = "--list" ]; then
  LIST_FILE="$2"
  [ -f "$LIST_FILE" ] || { echo "ERROR: list file not found"; exit 1; }
else
  INPUTS=("$@")
  [ "${#INPUTS[@]}" -ge 2 ] || { echo "ERROR: need ≥2 inputs"; exit 1; }
fi
```

### Step 2 — Detect codec uniformity

```bash
CODECS=()
RATES=()
for f in "${INPUTS[@]}"; do
  C=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$f")
  R=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$f")
  CODECS+=("$C")
  RATES+=("$R")
done
UNIQ_C=$(printf "%s\n" "${CODECS[@]}" | sort -u | wc -l)
UNIQ_R=$(printf "%s\n" "${RATES[@]}" | sort -u | wc -l)
```

### Step 3 — Fast path: concat demuxer (same codec + same sample rate)

```bash
if [ "$UNIQ_C" -eq 1 ] && [ "$UNIQ_R" -eq 1 ] && [ -z "$LIST_FILE" ]; then
  TMP_LIST=$(mktemp /tmp/concat.XXXXXX.txt)
  for f in "${INPUTS[@]}"; do
    printf "file '%s'\n" "$(realpath "$f")" >> "$TMP_LIST"
  done
  ffmpeg -y -f concat -safe 0 -i "$TMP_LIST" -c copy "$OUTPUT"
  rm "$TMP_LIST"
fi
```

If `--list` was supplied, just pass it through:

```bash
if [ -n "$LIST_FILE" ]; then
  ffmpeg -y -f concat -safe 0 -i "$LIST_FILE" -c copy "$OUTPUT" || \
    ffmpeg -y -f concat -safe 0 -i "$LIST_FILE" -c:a libmp3lame -b:a 192k "$OUTPUT"
fi
```

### Step 4 — Filter path: concat filter (mixed codecs/rates)

```bash
if [ "$UNIQ_C" -gt 1 ] || [ "$UNIQ_R" -gt 1 ]; then
  ARGS=()
  for f in "${INPUTS[@]}"; do ARGS+=(-i "$f"); done
  N="${#INPUTS[@]}"
  FILTER=""
  for ((i=0; i<N; i++)); do FILTER+="[$i:a]"; done
  FILTER+="concat=n=${N}:v=0:a=1[out]"

  EXT="${OUTPUT##*.}"
  case "$EXT" in
    mp3) CODEC="libmp3lame -b:a 192k" ;;
    aac|m4a) CODEC="aac -b:a 192k" ;;
    wav) CODEC="pcm_s16le" ;;
    flac) CODEC="flac" ;;
    *) CODEC="libmp3lame -b:a 192k" ;;
  esac

  ffmpeg -y "${ARGS[@]}" -filter_complex "$FILTER" -map "[out]" -c:a $CODEC "$OUTPUT"
fi
```

### Step 5 — Verify

```bash
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT"
```

## Output Contract

```
## Audio merge

**Inputs:**    <N> files
**Output:**    <output>
**Method:**    concat demuxer (lossless) | concat filter (re-encoded)
**Duration:**  <s>s (sum of inputs)
**Size:**      <KB>
```

## Gotchas

- **concat demuxer hard requirement**: all inputs must share codec, sample rate, AND channel count. Even tiny differences (44100 vs 48000) make it fail with `Non-monotonic DTS`. Probe before assuming.
- **List file path quirk**: `-safe 0` allows absolute paths. Without it, concat refuses anything containing `/`.
- **Mp3 join gaps/clicks**: concat-copying mp3 sometimes leaves a tiny silence at boundaries (frame alignment). Use the filter path with re-encode if click is audible.
- **realpath on macOS**: macOS ships `realpath` in coreutils only if `brew install coreutils` was run. Fall back to `python3 -c "import os; print(os.path.abspath('$f'))"`.
- **Order matters**: arguments are concatenated in the order given. Re-order to change sequence.

## Cross-Platform Notes

- **macOS**: `brew install ffmpeg coreutils` covers realpath.
- **Linux**: standard ffmpeg + coreutils.
- **Windows**: PowerShell `Resolve-Path` substitutes for realpath.
