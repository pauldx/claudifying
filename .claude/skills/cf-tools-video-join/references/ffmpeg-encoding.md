# FFmpeg Encoding Reference

## Concat Demuxer (lossless join)

```bash
# Create concat list
cat > /tmp/concat_list.txt << 'EOF'
file '/path/to/video1.mov'
file '/path/to/video2.mov'
EOF

# Stream copy (no re-encoding, fast)
ffmpeg -f concat -safe 0 -i /tmp/concat_list.txt -c copy output.mp4

# Re-encode with H.265
ffmpeg -f concat -safe 0 -i /tmp/concat_list.txt \
  -c:v libx265 -crf 28 -preset medium -r 30 \
  -vf "scale=1920:-2" \
  -c:a aac -b:a 128k \
  -tag:v hvc1 -movflags +faststart \
  output.mp4
```

## CRF Quality Scale (H.265)

| CRF | Quality | Use Case |
|-----|---------|----------|
| 18  | Visually lossless | Archival |
| 23  | High quality | Presentations, demos |
| 28  | Good quality | General sharing (default) |
| 32  | Acceptable | Chat/email, quick reviews |
| 38  | Low quality | Thumbnails, previews |

## Preset Speed vs Compression

| Preset | Speed | File Size |
|--------|-------|-----------|
| ultrafast | Fastest | Largest |
| fast | Fast | Larger |
| medium | Balanced | Balanced (recommended) |
| slow | Slow | Smaller |
| veryslow | Slowest | Smallest |

## Probing Video Info

```bash
# Full JSON metadata
ffprobe -v quiet -print_format json -show_streams -show_format input.mov

# Quick summary
ffprobe -v quiet -show_entries format=duration,size,bit_rate \
  -show_entries stream=codec_name,width,height,r_frame_rate \
  -print_format json input.mov
```

## Common Gotchas

- `-safe 0` required when concat list uses absolute paths
- `-tag:v hvc1` required for Apple/iOS H.265 playback
- `-movflags +faststart` moves moov atom for web streaming
- `scale=W:-2` keeps aspect ratio and ensures even height (required by H.264/H.265)
- Screen recordings: 120fps tbr is common — use `-r 30` to normalize
