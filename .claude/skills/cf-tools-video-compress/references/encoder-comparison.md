# Encoder Comparison Reference

## Full FFmpeg Command Templates

### H.265 (HEVC) — Default, best all-around
```bash
ffmpeg -i input.mov \
  -c:v libx265 -crf 28 -preset medium \
  -r 30 -vf "scale=1920:-2" \
  -c:a aac -b:a 128k \
  -tag:v hvc1 -movflags +faststart \
  output.mp4
```

### H.264 (AVC) — Maximum compatibility
```bash
ffmpeg -i input.mov \
  -c:v libx264 -crf 23 -preset medium \
  -r 30 -vf "scale=1920:-2" \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  output.mp4
```

### AV1 — Smallest file size
```bash
ffmpeg -i input.mov \
  -c:v libsvtav1 -crf 35 -preset 6 \
  -r 30 -vf "scale=1920:-2" \
  -c:a libopus -b:a 128k \
  output.mp4
```

### VP9 — Web/WebM
```bash
ffmpeg -i input.mov \
  -c:v libvpx-vp9 -crf 30 -b:v 0 \
  -r 30 -vf "scale=1920:-2" \
  -c:a libopus -b:a 128k \
  output.webm
```

### Container swap only (no re-encode)
```bash
ffmpeg -i input.mov -c copy output.mp4
```

## CRF Equivalence Across Encoders

To get roughly similar visual quality across encoders:

| Quality | H.265 CRF | H.264 CRF | AV1 CRF | VP9 CRF |
|---------|-----------|-----------|---------|---------|
| Lossless | 0 | 0 | 0 | 0 |
| Very High | 20 | 16 | 25 | 20 |
| High | 23 | 19 | 30 | 25 |
| Balanced | 28 | 23 | 35 | 30 |
| Low | 32 | 27 | 40 | 35 |
| Very Low | 36 | 31 | 45 | 40 |

## Checking Available Encoders

```bash
# List all video encoders
ffmpeg -encoders 2>/dev/null | grep '^ V'

# Check specific encoder
ffmpeg -encoders 2>/dev/null | grep libx265
ffmpeg -encoders 2>/dev/null | grep libsvtav1
ffmpeg -encoders 2>/dev/null | grep libvpx
```

## Scaling Reference

```bash
# Scale to max 1920 wide, maintain aspect ratio, ensure even height
-vf "scale=1920:-2"

# Scale to max 1280 wide
-vf "scale=1280:-2"

# Scale to 50% of original
-vf "scale=iw/2:-2"

# Only scale down, never up
-vf "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease"
```
