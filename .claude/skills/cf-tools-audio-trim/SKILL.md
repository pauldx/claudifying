---
name: cf-tools-audio-trim
description: "Cut a segment from an audio file by start/end or duration, lossless when possible. Trigger: /cf-tools-audio-trim"
trigger: /cf-tools-audio-trim
version: 1.0.0
---

# /cf-tools-audio-trim

Cut a clip out of an audio file. Uses stream-copy (no re-encode) when the cut points are codec-friendly, so it's fast and lossless. Falls back to re-encode only when frame-accurate trim is required.

## Usage

```
/cf-tools-audio-trim input.mp3 output.mp3 --start 0:30
/cf-tools-audio-trim input.mp3 output.mp3 --start 0:30 --end 2:15
/cf-tools-audio-trim input.wav output.wav --start 5 --duration 30
/cf-tools-audio-trim input.mp3 output.mp3 --start 00:01:30 --end 00:02:00 --accurate
```

Arguments:
1. `input` (required)
2. `output` (required)
3. `--start <time>` (required) — `SS`, `MM:SS`, or `HH:MM:SS`
4. `--end <time>` OR `--duration <seconds>` (one required)
5. `--accurate` (optional flag) — force re-encode for frame-accurate cut

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; OUTPUT="$2"; shift 2
START=""; END=""; DUR=""; ACCURATE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --start) START="$2"; shift 2 ;;
    --end) END="$2"; shift 2 ;;
    --duration) DUR="$2"; shift 2 ;;
    --accurate) ACCURATE=1; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done
[ -f "$INPUT" ] || { echo "ERROR: input not found"; exit 1; }
[ -n "$START" ] || { echo "ERROR: --start required"; exit 1; }
```

### Step 2 — Fast path: stream-copy

`-ss` before `-i` is fast seek (keyframe-aligned). `-c copy` skips re-encode.

```bash
if [ "$ACCURATE" -eq 0 ]; then
  if [ -n "$END" ]; then
    ffmpeg -y -ss "$START" -to "$END" -i "$INPUT" -c copy "$OUTPUT"
  elif [ -n "$DUR" ]; then
    ffmpeg -y -ss "$START" -t "$DUR" -i "$INPUT" -c copy "$OUTPUT"
  fi
fi
```

### Step 3 — Accurate path: re-encode

`-ss` after `-i` is slow but sample-accurate.

```bash
if [ "$ACCURATE" -eq 1 ]; then
  EXT="${OUTPUT##*.}"
  case "$EXT" in
    mp3) CODEC="libmp3lame -b:a 192k" ;;
    aac|m4a) CODEC="aac -b:a 192k" ;;
    wav) CODEC="pcm_s16le" ;;
    flac) CODEC="flac" ;;
    opus) CODEC="libopus -b:a 96k" ;;
    ogg) CODEC="libvorbis -q:a 5" ;;
    *) CODEC="copy" ;;
  esac
  if [ -n "$END" ]; then
    ffmpeg -y -i "$INPUT" -ss "$START" -to "$END" -c:a $CODEC "$OUTPUT"
  else
    ffmpeg -y -i "$INPUT" -ss "$START" -t "$DUR" -c:a $CODEC "$OUTPUT"
  fi
fi
```

### Step 4 — Verify

```bash
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT"
```

## Output Contract

```
## Audio trim

**Source:**     <input>
**Output:**     <output>
**Range:**      <start> → <end> (<duration>s)
**Method:**     stream-copy (fast) | re-encode (accurate)
**Result size:** <KB>
```

## Gotchas

- **MP3 stream-copy clicks at start**: MP3 frames are ~26 ms long. Stream-copy snaps to the nearest frame boundary, so you may hear a tiny click. Use `--accurate` to eliminate it.
- **WAV/FLAC are always sample-accurate**: stream-copy on PCM is sample-accurate by definition; no need for `--accurate`.
- **End time must be after start**: ffmpeg silently produces an empty file if `--end < --start`. Validate before running.
- **HH:MM:SS.mmm**: milliseconds allowed (`--start 1:23.500`). Useful for precise edits.
- **Negative duration in metadata**: if you see this in the output, the input had broken timestamps — re-encode with `--accurate` to fix.

## Cross-Platform Notes

Same ffmpeg invocation works on macOS, Linux, Windows. Stream-copy path is essentially instant (no codec work).
