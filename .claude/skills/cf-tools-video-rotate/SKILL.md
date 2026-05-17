---
name: cf-tools-video-rotate
description: "Rotate a video 90/180/270 degrees or flip horizontally/vertically. Trigger: /cf-tools-video-rotate"
trigger: /cf-tools-video-rotate
version: 1.0.0
---

# /cf-tools-video-rotate

Rotate by 90, 180, or 270 degrees or mirror-flip horizontally/vertically. Uses ffmpeg's `transpose` and `hflip` / `vflip` filters — frame-accurate, lossless aspect handling.

Related skills:
- `/cf-tools-video-resize` — change resolution after rotation
- `/cf-tools-video-metadata` — confirm orientation tag

## Usage

```
/cf-tools-video-rotate input.mp4 --angle 90
/cf-tools-video-rotate input.mp4 --angle 180
/cf-tools-video-rotate input.mp4 --angle 270 --output rotated.mp4
/cf-tools-video-rotate input.mp4 --flip horizontal
/cf-tools-video-rotate input.mp4 --flip vertical
```

Arguments:
1. `input` (required)
2. `--angle 90 | 180 | 270` OR `--flip horizontal | vertical` (one required)
3. `--output PATH` (default `<stem>-rot.mp4`)

## What You Must Do When Invoked

### Step 1 — Build the filter

| Operation | ffmpeg filter |
|---|---|
| 90° clockwise | `transpose=1` |
| 180° | `transpose=2,transpose=2` |
| 270° clockwise (= 90° CCW) | `transpose=2` |
| Flip horizontal | `hflip` |
| Flip vertical | `vflip` |

### Step 2 — Encode

```bash
ffmpeg -y -i "$INPUT" -vf "$FILTER" \
  -c:v libx264 -preset medium -crf 23 \
  -c:a copy \
  -metadata:s:v:0 rotate=0 \
  -movflags +faststart \
  "$OUTPUT"
```

`-metadata:s:v:0 rotate=0` strips any existing rotation metadata so players don't double-rotate.

### Step 3 — Verify dimensions

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$OUTPUT"
```

For 90/270 rotations the width and height should swap. For 180/flips they stay the same.

## Output Contract

```
## Video rotate

**Source:**   <input>  (<inW>x<inH>)
**Operation:** angle=<N> | flip=<axis>
**Output:**   <output> (<outW>x<outH>)
**Audio:**    stream-copied (no re-encode)
```

## Gotchas

- Some phone videos carry a `rotate=90` metadata tag and have unrotated pixels. Players honor the tag; transcoders may not. Always strip the tag with `-metadata:s:v:0 rotate=0` after applying the rotation filter, otherwise the result looks rotated twice.
- `transpose=1` is 90° CW with vertical flip; `transpose=2` is 90° CCW with vertical flip. The table above accounts for this.
- Audio is stream-copied — fast and lossless. If the source has no audio, ffmpeg silently omits it.
- Re-encoding is required (no stream-copy path) because the pixel grid changes.

## Cross-Platform Notes

Works identically across macOS, Linux, Windows. Apple Silicon: pass `-c:v h264_videotoolbox -b:v 4M` instead of libx264 for ~3× faster encode at slightly lower visual quality.
