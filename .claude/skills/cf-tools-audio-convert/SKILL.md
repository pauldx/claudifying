---
name: cf-tools-audio-convert
description: "Convert audio between formats (mp3, wav, flac, aac, ogg, opus) via ffmpeg with sane codec defaults. Trigger: /cf-tools-audio-convert"
trigger: /cf-tools-audio-convert
version: 1.0.0
---

# /cf-tools-audio-convert

Swap audio container/codec with one command. Sensible defaults for each target format. Lossless containers (wav, flac) stay lossless; lossy targets get tuned bitrates.

## Usage

```
/cf-tools-audio-convert input.wav output.mp3
/cf-tools-audio-convert input.mp3 output.flac
/cf-tools-audio-convert input.flac output.opus
/cf-tools-audio-convert input.mp3 output.aac 256k     # custom bitrate
```

Arguments:
1. `input` (required) — source audio path
2. `output` (required) — target audio path; extension drives the codec choice
3. `bitrate` (optional) — override default lossy bitrate (e.g. `192k`, `256k`, `320k`)

## Codec Defaults

| Output ext | Codec       | Default bitrate | Sample rate |
|------------|-------------|-----------------|-------------|
| `.mp3`     | libmp3lame  | 192k            | source      |
| `.aac` / `.m4a` | aac    | 192k            | source      |
| `.opus`    | libopus     | 96k             | source      |
| `.ogg`     | libvorbis   | -q:a 5 (~160k)  | source      |
| `.wav`     | pcm_s16le   | lossless        | source      |
| `.flac`    | flac        | lossless (-8)   | source      |

## What You Must Do When Invoked

### Step 1 — Validate input and target

```bash
INPUT="$1"
OUTPUT="$2"
BITRATE="${3:-}"

[ -f "$INPUT" ] || { echo "ERROR: input not found: $INPUT"; exit 1; }
[ -n "$OUTPUT" ] || { echo "ERROR: output path required"; exit 1; }
EXT="${OUTPUT##*.}"
EXT_LC=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
```

### Step 2 — Dispatch by target extension

```bash
case "$EXT_LC" in
  mp3)
    BR="${BITRATE:-192k}"
    ffmpeg -y -i "$INPUT" -c:a libmp3lame -b:a "$BR" "$OUTPUT"
    ;;
  aac|m4a)
    BR="${BITRATE:-192k}"
    ffmpeg -y -i "$INPUT" -c:a aac -b:a "$BR" "$OUTPUT"
    ;;
  opus)
    BR="${BITRATE:-96k}"
    ffmpeg -y -i "$INPUT" -c:a libopus -b:a "$BR" "$OUTPUT"
    ;;
  ogg)
    ffmpeg -y -i "$INPUT" -c:a libvorbis -q:a 5 "$OUTPUT"
    ;;
  wav)
    ffmpeg -y -i "$INPUT" -c:a pcm_s16le "$OUTPUT"
    ;;
  flac)
    ffmpeg -y -i "$INPUT" -c:a flac -compression_level 8 "$OUTPUT"
    ;;
  *)
    echo "ERROR: unsupported target extension: $EXT_LC"
    echo "Supported: mp3, aac, m4a, opus, ogg, wav, flac"
    exit 1
    ;;
esac
```

### Step 3 — Verify

```bash
ffprobe -v error -show_entries format=duration,size,bit_rate -show_entries stream=codec_name,sample_rate,channels -of default=noprint_wrappers=1 "$OUTPUT"
```

## Output Contract

```
## Audio conversion

**Source:**   <input>
**Output:**   <output>
**Codec:**    <codec> @ <bitrate or "lossless">
**Duration:** <s>s
**Size:**     <bytes / KB>
```

## Gotchas

- **Cannot downsample bitrate by re-encoding lossy → same lossy**: re-encoding mp3 → mp3 at lower bitrate compounds artifacts. Always go to wav/flac first if you need to manipulate, then re-encode.
- **Opus at high bitrates wastes bytes**: opus saturates around 128k. Don't push it past that; use aac or mp3 for >192k targets.
- **m4a vs aac**: `.m4a` is an MP4 container holding AAC. ffmpeg infers from extension; both work the same here.
- **Sample rate mismatch warnings**: opus only supports 8/12/16/24/48 kHz. ffmpeg auto-resamples 44.1 → 48 silently; no action needed.
- **VBR vs CBR**: defaults use CBR for mp3/aac. For VBR mp3 use `-q:a 2` instead of `-b:a`.

## Cross-Platform Notes

- **macOS**: `brew install ffmpeg` ships with libmp3lame, libopus, libvorbis, aac.
- **Linux**: `apt install ffmpeg` — same codec coverage on modern distros.
- **Windows**: gyan.dev or BtbN builds include all codecs above.

Verify codecs available via `ffmpeg -codecs | grep -E "mp3|aac|opus|vorbis|flac"`.
