---
name: cf-tools-video-resize
description: "Resize a video by width/height or scale factor, preserving aspect or letterboxing. Trigger: /cf-tools-video-resize"
trigger: /cf-tools-video-resize
version: 1.0.0
---

# /cf-tools-video-resize

Change a video's resolution. Default preserves aspect ratio with an even-pixel constraint (required by yuv420p). Optional `--letterbox` pads to a fixed target to avoid any cropping.

Related skills:
- `/cf-tools-video-rotate` — orientation
- `/cf-tools-video-compress` — bitrate/CRF tuning after resize

## Usage

```
/cf-tools-video-resize input.mp4 --width 1280                  # height auto, keep aspect
/cf-tools-video-resize input.mp4 --height 720
/cf-tools-video-resize input.mp4 --width 1920 --height 1080    # cropped/stretched (see flags)
/cf-tools-video-resize input.mp4 --scale 0.5
/cf-tools-video-resize input.mp4 --width 1080 --height 1920 --letterbox  # vertical pad
```

Arguments:
1. `input` (required)
2. `--width N` and/or `--height N` OR `--scale FLOAT` (one mode required)
3. `--letterbox` (optional) — pad with black bars instead of stretch/crop when both W and H given
4. `--output PATH` (default `<stem>-<WxH>.mp4`)

## What You Must Do When Invoked

### Step 1 — Determine target filter

Width-only (aspect preserved, height auto, force even):
```
scale=W:-2
```

Height-only:
```
scale=-2:H
```

Scale factor:
```
scale=trunc(iw*F/2)*2:trunc(ih*F/2)*2
```

Both W+H, no letterbox (stretch — usually not what user wants):
```
scale=W:H
```

Both W+H with `--letterbox` (preferred for fixed targets):
```
scale=W:H:force_original_aspect_ratio=decrease,pad=W:H:(ow-iw)/2:(oh-ih)/2:black,setsar=1
```

### Step 2 — Encode

```bash
ffmpeg -y -i "$INPUT" -vf "$VF" \
  -c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p \
  -c:a copy \
  -movflags +faststart \
  "$OUTPUT"
```

### Step 3 — Verify

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$OUTPUT"
```

## Output Contract

```
## Video resize

**Source:**   <input>   (<inW>x<inH>)
**Target:**   <WxH>  (mode: scale | width-only | height-only | letterbox)
**Output:**   <output> (<outW>x<outH>)
**Aspect:**   preserved | stretched | letterboxed
```

## Gotchas

- `yuv420p` requires both width and height to be even. Always use `-2` (auto + round to even) instead of `-1` for the auto dimension.
- Stretching (both W and H without letterbox) distorts the image — warn the user; recommend `--letterbox` or single-dim.
- Upscaling won't add detail. Above 1.5× scale, suggest `-vf "scale=W:H:flags=lanczos"` for sharper output.
- Don't combine `--scale` with `--width` / `--height` — reject with an error.
- `setsar=1` after pad ensures square pixels; without it some players show the result stretched.

## Cross-Platform Notes

Pure ffmpeg, portable. Apple Silicon hardware encode: `-c:v h264_videotoolbox -b:v 5M` (no CRF in VT mode). For HDR / 10-bit sources, swap `yuv420p` for `yuv420p10le` and use `libx265`.
