---
name: cf-tools-video-mute
description: "Remove the audio track from a video without re-encoding the video stream. Trigger: /cf-tools-video-mute"
trigger: /cf-tools-video-mute
version: 1.0.0
---

# /cf-tools-video-mute

Strip the audio stream from a video file. Stream-copies the video so the output is bit-identical to the source — only the audio is dropped. Sub-second for any size of input.

Related skills:
- `/cf-tools-video-dub` — replace audio instead of remove
- `/cf-tools-video-speed` — speed change (drops/rebuilds audio anyway)

## Usage

```
/cf-tools-video-mute input.mp4
/cf-tools-video-mute input.mp4 --output silent.mp4
/cf-tools-video-mute input.mov --keep-subtitles
```

Arguments:
1. `input` (required)
2. `--output PATH` (default `<stem>-muted.<ext>`)
3. `--keep-subtitles` (optional) — preserve subtitle streams (default: keep)

## What You Must Do When Invoked

### Step 1 — Check audio presence

```bash
HAS_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$INPUT" | head -1)
if [ -z "$HAS_AUDIO" ]; then
  echo "ℹ️  No audio streams in source. Output will be a copy."
fi
```

### Step 2 — Stream-copy with no audio

```bash
ffmpeg -y -i "$INPUT" -an -c:v copy -c:s copy "$OUTPUT"
```

Notes:
- `-an` drops audio.
- `-c:v copy` stream-copies video (lossless, fast).
- `-c:s copy` preserves subtitles (drop if `--no-subtitles`).

### Step 3 — Verify silence

```bash
AUDIO_AFTER=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$OUTPUT" | wc -l | tr -d ' ')
echo "Audio streams after mute: $AUDIO_AFTER (expected 0)"
```

## Output Contract

```
## Video mute

**Source:**       <input>
**Output:**       <output>
**Streams in:**   video=<N> audio=<M> subs=<K>
**Streams out:**  video=<N> audio=0 subs=<K|0>
**Duration:**     unchanged (stream-copied)
```

## Gotchas

- Some containers (`.avi`, old `.mov`) reject `-c:s copy` if subtitles are in a format the container can't hold. If ffmpeg errors, retry without subtitle copy.
- A "muted" track at low volume is NOT the same as removed — this skill removes the stream entirely. Use `-af "volume=0"` instead if you must keep the audio track but silent.
- If you want to keep the audio stream but silence it (some editors require an audio track), use:
  `ffmpeg -i in -c:v copy -af "volume=0" -c:a aac out.mp4` — note this re-encodes audio.
- Output file size drops by exactly the size of the audio stream, typically 10–20% for AAC.

## Cross-Platform Notes

Identical ffmpeg invocation across all platforms. No hardware acceleration needed (no video transcode happens).
