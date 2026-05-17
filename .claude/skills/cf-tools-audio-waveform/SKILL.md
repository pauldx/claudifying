---
name: cf-tools-audio-waveform
description: "Render a PNG waveform image of an audio file using ffmpeg showwavespic. Trigger: /cf-tools-audio-waveform"
trigger: /cf-tools-audio-waveform
version: 1.0.0
---

# /cf-tools-audio-waveform

Generate a static PNG visualization of an audio waveform. Useful for podcast cover art, dataset thumbnails, or social-media post previews.

## Usage

```
/cf-tools-audio-waveform input.mp3 waveform.png
/cf-tools-audio-waveform input.mp3 waveform.png --size 1600x400
/cf-tools-audio-waveform input.mp3 waveform.png --color "#1DB954" --bg "#191414"
/cf-tools-audio-waveform input.mp3 waveform.png --draw full --split-channels
```

Arguments:
1. `input` (required)
2. `output` (required) — `.png` path
3. `--size <WxH>` (optional, default `1200x300`)
4. `--color <hex>` (optional, default `#3DD68C`) — waveform colour
5. `--bg <hex>` (optional, default `#000000`) — background colour
6. `--draw <scale|full>` (optional, default `full`) — `full` = solid pixels, `scale` = amplitude-shaded
7. `--scale <lin|log|sqrt|cbrt>` (optional, default `lin`) — amplitude curve
8. `--split-channels` (optional flag) — stack stereo as two waveforms

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; OUTPUT="$2"; shift 2
SIZE="1200x300"; COLOR="#3DD68C"; BG="#000000"; DRAW="full"; SCALE="lin"; SPLIT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --size) SIZE="$2"; shift 2 ;;
    --color) COLOR="$2"; shift 2 ;;
    --bg) BG="$2"; shift 2 ;;
    --draw) DRAW="$2"; shift 2 ;;
    --scale) SCALE="$2"; shift 2 ;;
    --split-channels) SPLIT=1; shift ;;
    *) shift ;;
  esac
done
[ -f "$INPUT" ] || { echo "ERROR: input not found"; exit 1; }
```

### Step 2 — Normalise colors (strip leading #)

ffmpeg's showwavespic uses `0x` prefix or named colors; passing `#RRGGBB` works in modern builds but is fragile. Use the `0x` form.

```bash
to_hex() { echo "${1#\#}"; }
COLOR_HEX="0x$(to_hex "$COLOR")"
BG_HEX="0x$(to_hex "$BG")"
```

### Step 3 — Render

```bash
SPLIT_FLAG=0
[ "$SPLIT" -eq 1 ] && SPLIT_FLAG=1

ffmpeg -y -i "$INPUT" \
  -filter_complex "showwavespic=s=${SIZE}:colors=${COLOR_HEX}:split_channels=${SPLIT_FLAG}:draw=${DRAW}:scale=${SCALE}" \
  -frames:v 1 -update 1 "$OUTPUT"
```

Note: showwavespic does **not** paint a background — the area outside the wave is transparent. To add a solid background, composite:

```bash
ffmpeg -y \
  -f lavfi -i "color=c=${BG_HEX}:s=${SIZE}" \
  -i "$INPUT" \
  -filter_complex "[1:a]showwavespic=s=${SIZE}:colors=${COLOR_HEX}:split_channels=${SPLIT_FLAG}:draw=${DRAW}:scale=${SCALE}[wave];[0:v][wave]overlay=format=auto" \
  -frames:v 1 -update 1 "$OUTPUT"
```

### Step 4 — Verify

```bash
# PNG must exist and be non-zero
[ -s "$OUTPUT" ] || { echo "ERROR: empty output"; exit 1; }
# Inspect via ffprobe (yes, PNG is a valid image stream)
ffprobe -v error -show_entries stream=width,height -of default=noprint_wrappers=1 "$OUTPUT"
```

## Output Contract

```
## Audio waveform

**Source:**       <input>
**Output PNG:**   <output>
**Size:**         <WxH>
**Color:**        <color> on <bg>
**Draw:**         <draw> (split_channels: yes|no, scale: <scale>)
**Duration:**     <s>s (source)
```

## Draw / Scale Reference

`showwavespic` (static picture) is a different filter from `showwaves` (animated video). It accepts:

| `draw` value | Effect |
|--------------|--------|
| `scale` (default in raw ffmpeg) | each pixel intensity reflects amplitude — thin trace, anti-aliased |
| `full`       | solid pixel for every sample crossing — bolder waveform, recommended for thumbnails |

| `scale` value | Amplitude curve |
|---------------|------------------|
| `lin` (default) | linear |
| `log`           | log — emphasises quiet detail |
| `sqrt`          | square root |
| `cbrt`          | cubic root |

If you need *animated* waveforms (overlaid on video), use the `showwaves` filter instead — it has the `line / p2p / cline / point` modes mentioned in older guides.

## Gotchas

- **Transparent background by default**: ignore this and you get a wave on a black void in some viewers. The composite trick above fixes it.
- **Color format**: `#RRGGBB` works in ffmpeg 6+, but `0xRRGGBB` is the safe, documented form.
- **Long files render slow**: 2-hour podcast → ~5-10 seconds. Render time roughly linear in audio duration.
- **Stereo blends by default**: a busy mix looks muddy. Add `--split-channels` to stack L/R for clarity.
- **`-frames:v 1` warning about image sequences**: ffmpeg recommends adding `-update 1` to silence the `%d` pattern warning. Already included in the commands above.
- **Don't confuse with `showwaves`**: `showwaves` is the animated/video version and has different options (line, p2p, cline, point modes). `showwavespic` is the static picture variant — only `scale`/`full` for `draw`.
- **Pixel-resolution**: `--size 1200x300` is fine for thumbnails. For print, use `2400x600` or larger.
- **No DC offset compensation**: if your source has DC bias, the waveform looks vertically shifted. Run through `cf-tools-audio-normalize` first.

## Cross-Platform Notes

showwavespic is core ffmpeg. Same command across macOS / Linux / Windows. PNG output is universal.
