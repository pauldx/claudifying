---
name: cf-tools-video-trim
description: "Cut a segment from a video by start/end timestamps or duration. Trigger: /cf-tools-video-trim"
trigger: /cf-tools-video-trim
version: 1.0.0
---

# /cf-tools-video-trim

Extract a clean segment from a video file without re-encoding when possible. Uses ffmpeg stream-copy for fast, lossless trims when the cut points align with keyframes; falls back to re-encode (libx264 CRF 23) when frame-accurate cuts are required.

Related skills:
- `/cf-tools-video-speed` — change playback rate
- `/cf-tools-video-loop` — repeat a clip
- `/cf-tools-video-metadata` — inspect duration before trimming

## Usage

```
/cf-tools-video-trim input.mp4 --start 00:00:02 --end 00:00:04
/cf-tools-video-trim input.mp4 --start 00:00:02 --duration 2
/cf-tools-video-trim input.mp4 --start 5 --duration 10 --output cut.mp4
/cf-tools-video-trim input.mp4 --start 00:00:02 --end 00:00:04 --accurate
```

Arguments:
1. `input` (required) — source video path
2. `--start HH:MM:SS | seconds` (required) — cut start
3. `--end HH:MM:SS | seconds` or `--duration N` (one required) — cut endpoint
4. `--output PATH` (optional, default `<stem>-trim.mp4`) — destination
5. `--accurate` (optional flag) — force re-encode for frame-accurate cuts

## What You Must Do When Invoked

### Step 1 — Validate input

```bash
INPUT="$1"
if [ ! -f "$INPUT" ]; then
  echo "ERROR: input not found: $INPUT"; exit 1
fi
ffprobe -v error -i "$INPUT" -show_entries format=duration -of csv=p=0 >/dev/null \
  || { echo "ERROR: ffprobe cannot read $INPUT"; exit 1; }
```

### Step 2 — Resolve start / end / duration

If `--end` given, compute `duration = end - start`. If `--duration` given, use directly. Reject overlapping or zero/negative durations.

### Step 3 — Run ffmpeg

Fast (stream copy) — default:

```bash
ffmpeg -y -ss "$START" -i "$INPUT" -t "$DURATION" -c copy -avoid_negative_ts make_zero "$OUTPUT"
```

Accurate (re-encode) — when `--accurate`:

```bash
ffmpeg -y -ss "$START" -i "$INPUT" -t "$DURATION" \
  -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k \
  -movflags +faststart "$OUTPUT"
```

### Step 4 — Verify

```bash
ACTUAL=$(ffprobe -v error -i "$OUTPUT" -show_entries format=duration -of csv=p=0)
echo "Expected ~${DURATION}s, actual ${ACTUAL}s"
```

## Output Contract

```
## Video trim

**Source:**   <input>
**Output:**   <output>
**Range:**    <start> → <end>  (<duration>s)
**Mode:**     stream-copy | re-encode
**Verified:** ffprobe duration <Ns>
```

## Gotchas

- Stream-copy can over/undershoot by up to one GOP (typically 0.5–2s). Use `--accurate` for exact cuts.
- Putting `-ss` before `-i` is fast input seek; putting `-ss` after `-i` is slower but frame-accurate. The skill places `-ss` before for speed and uses `-accurate` to switch to post-input seek with re-encode.
- Some containers (`.mkv`, `.webm`) need `-c copy -copyts` to preserve timestamps.
- Audio-only sources still work — ffmpeg auto-detects streams.

## Cross-Platform Notes

ffmpeg is universal (macOS `brew install ffmpeg`, Linux `apt install ffmpeg`, Windows from gyan.dev builds). On Apple Silicon you may pass `-hwaccel videotoolbox` for decode speed, but stream-copy already avoids decode.
