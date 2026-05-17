---
name: cf-tools-audio-extract-from-video
description: "Extract the audio track from a video file — lossless stream-copy or re-encode to mp3/aac. Trigger: /cf-tools-audio-extract-from-video"
trigger: /cf-tools-audio-extract-from-video
version: 1.0.0
---

# /cf-tools-audio-extract-from-video

Pull the audio track out of a video container. By default, stream-copies the source codec (lossless, fast). Optionally transcodes to mp3, aac, or wav.

## Usage

```
/cf-tools-audio-extract-from-video input.mp4 output.aac           # stream-copy (lossless)
/cf-tools-audio-extract-from-video input.mov output.mp3           # transcode to mp3
/cf-tools-audio-extract-from-video input.mkv output.wav           # transcode to wav
/cf-tools-audio-extract-from-video input.mp4 output.mp3 --bitrate 320k
/cf-tools-audio-extract-from-video input.mp4 output.aac --track 1 # pick a non-default audio track
```

Arguments:
1. `input` (required) — video path
2. `output` (required) — audio path; extension picks the strategy
3. `--bitrate <kbps>` (optional, default 192k for lossy)
4. `--track <N>` (optional, default 0) — select audio stream by index

## Strategy

| Output ext      | Source codec match? | Method               |
|-----------------|---------------------|----------------------|
| `.aac` / `.m4a` | source is AAC       | stream-copy          |
| `.aac` / `.m4a` | source is not AAC   | transcode to AAC     |
| `.mp3`          | always              | transcode to mp3     |
| `.wav`          | always              | transcode to pcm_s16le |
| `.flac`         | always              | transcode to flac    |
| `.opus`         | source is opus      | stream-copy          |
| `.opus`         | source is not opus  | transcode to opus    |

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; OUTPUT="$2"; shift 2
BITRATE="192k"; TRACK="0"
while [ $# -gt 0 ]; do
  case "$1" in
    --bitrate) BITRATE="$2"; shift 2 ;;
    --track) TRACK="$2"; shift 2 ;;
    *) shift ;;
  esac
done
```

### Step 2 — Probe source audio codec

```bash
SRC_CODEC=$(ffprobe -v error -select_streams "a:${TRACK}" \
  -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$INPUT")
[ -n "$SRC_CODEC" ] || { echo "ERROR: no audio stream at index $TRACK"; exit 1; }
```

### Step 3 — Dispatch

```bash
EXT="${OUTPUT##*.}"
EXT_LC=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

case "$EXT_LC" in
  aac|m4a)
    if [ "$SRC_CODEC" = "aac" ]; then
      ffmpeg -y -i "$INPUT" -map "0:a:${TRACK}" -vn -c:a copy "$OUTPUT"
    else
      ffmpeg -y -i "$INPUT" -map "0:a:${TRACK}" -vn -c:a aac -b:a "$BITRATE" "$OUTPUT"
    fi
    ;;
  mp3)
    ffmpeg -y -i "$INPUT" -map "0:a:${TRACK}" -vn -c:a libmp3lame -b:a "$BITRATE" "$OUTPUT"
    ;;
  wav)
    ffmpeg -y -i "$INPUT" -map "0:a:${TRACK}" -vn -c:a pcm_s16le "$OUTPUT"
    ;;
  flac)
    ffmpeg -y -i "$INPUT" -map "0:a:${TRACK}" -vn -c:a flac "$OUTPUT"
    ;;
  opus)
    if [ "$SRC_CODEC" = "opus" ]; then
      ffmpeg -y -i "$INPUT" -map "0:a:${TRACK}" -vn -c:a copy "$OUTPUT"
    else
      ffmpeg -y -i "$INPUT" -map "0:a:${TRACK}" -vn -c:a libopus -b:a 96k "$OUTPUT"
    fi
    ;;
  *)
    echo "ERROR: unsupported output extension: $EXT_LC"
    exit 1
    ;;
esac
```

### Step 4 — Verify

```bash
ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name,sample_rate,channels -of default=noprint_wrappers=1 "$OUTPUT"
```

## Output Contract

```
## Audio extract from video

**Source video:**  <input> (audio codec: <src_codec>)
**Output audio:**  <output> (codec: <out_codec>)
**Track index:**   <N>
**Method:**        stream-copy | transcode
**Duration:**      <s>s
**Size:**          <KB>
```

## Gotchas

- **Wrong file extension for the source codec**: extracting AAC into a `.mp3` file produces a corrupt mp3. Always either match the extension to the source codec OR transcode.
- **Multiple audio tracks**: international films often have 2-5 audio tracks. Use `ffprobe -show_streams "$INPUT"` to list; `--track 1` to pick the 2nd track.
- **Video container has no audio**: `ffprobe` returns empty `codec_name`. Validate before invoking ffmpeg.
- **AAC ADTS vs raw**: stream-copying AAC out of MP4 wraps it correctly in `.aac`. No special flags needed in ffmpeg 6+.
- **Webm with opus**: `.webm` → `.opus` is stream-copy; just rename essentially.

## Cross-Platform Notes

Same ffmpeg path on macOS, Linux, Windows. No external dependencies beyond ffmpeg.
