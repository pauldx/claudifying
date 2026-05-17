---
name: cf-tools-video-gif
description: "Convert a video to an optimized GIF using two-pass palettegen for small size and clean colors. Trigger: /cf-tools-video-gif"
trigger: /cf-tools-video-gif
version: 1.0.0
---

# /cf-tools-video-gif

Convert any video to a high-quality animated GIF. Uses ffmpeg's two-pass `palettegen` + `paletteuse` pipeline — a single-pass GIF is 3–10× larger and banded; this skill produces the smallest, cleanest GIF possible without resorting to gifsicle.

Related skills:
- `/cf-tools-video-trim` — cut the segment first (GIFs should be ≤ 10s)
- `/cf-tools-video-resize` — reduce dims before GIF for smaller output

## Usage

```
/cf-tools-video-gif input.mp4
/cf-tools-video-gif input.mp4 --fps 15 --width 480
/cf-tools-video-gif input.mp4 --fps 10 --width 320 --output preview.gif
/cf-tools-video-gif input.mp4 --start 2 --duration 4 --fps 12
```

Arguments:
1. `input` (required)
2. `--fps N` (default 15) — frames per second
3. `--width N` (default 480) — output width (height auto, aspect preserved)
4. `--start SECONDS` (optional) — clip start offset
5. `--duration SECONDS` (optional) — clip length
6. `--output PATH` (default `<stem>.gif`)

## What You Must Do When Invoked

### Step 1 — Build filter graph

```bash
FILTERS="fps=${FPS},scale=${WIDTH}:-1:flags=lanczos"
```

### Step 2 — Generate palette (pass 1)

```bash
PALETTE="$(mktemp -t gif-palette.XXXXX.png)"

# Optional trim args
TRIM_ARGS=()
[ -n "$START" ] && TRIM_ARGS+=(-ss "$START")
[ -n "$DURATION" ] && TRIM_ARGS+=(-t "$DURATION")

ffmpeg -y "${TRIM_ARGS[@]}" -i "$INPUT" \
  -vf "${FILTERS},palettegen=stats_mode=diff" \
  -update 1 -frames:v 1 "$PALETTE"
```

`-update 1 -frames:v 1` tells ffmpeg ≥ 7 to write a single PNG (not an image sequence). Older builds tolerated either form.

`stats_mode=diff` weights moving regions higher — better palette for animated content than the default `full`.

### Step 3 — Apply palette (pass 2)

```bash
ffmpeg -y "${TRIM_ARGS[@]}" -i "$INPUT" -i "$PALETTE" \
  -lavfi "${FILTERS} [v]; [v][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  "$OUTPUT"

rm -f "$PALETTE"
```

`dither=bayer:bayer_scale=5` is the sweet spot — less banding than `none`, less noise than `floyd_steinberg`. `diff_mode=rectangle` skips unchanged regions for smaller output.

### Step 4 — Verify

```bash
file "$OUTPUT"   # should be "GIF image data"
SIZE=$(du -h "$OUTPUT" | awk '{print $1}')
echo "GIF size: $SIZE"
```

## Output Contract

```
## Video → GIF

**Source:**   <input>
**Output:**   <output>
**FPS:**      <N>
**Width:**    <W>px (height auto)
**Clip:**     <start>–<end>s   (if trim)
**Size:**     <human-readable>
**Method:**   two-pass palettegen + bayer dither
```

## Gotchas

- Single-pass GIFs (no palette) look posterized and are ~5× larger. Always do two-pass.
- Width > 600 or FPS > 20 produces enormous GIFs (10+ MB for 5 seconds). Push back if user requests these without trim.
- GIFs do not loop natively in some players; ffmpeg sets infinite loop by default. To force-set, add `-loop 0`.
- For transparency in animated content, see `paletteuse=alpha_threshold=128` and a source with alpha (rare for video).
- macOS Quick Look ignores `diff_mode=rectangle` optimization and re-renders fully — file is still smaller on disk.

## Cross-Platform Notes

Works on any ffmpeg ≥ 4.x. `mktemp -t` differs between macOS (template `prefix.XXXXX`) and Linux (`prefix.XXXXXX`); the form above (`-t gif-palette.XXXXX.png`) works on both. If you need even smaller GIFs post-conversion, pipe through `gifsicle -O3` (optional, not required).
