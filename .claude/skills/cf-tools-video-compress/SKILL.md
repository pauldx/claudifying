---
name: cf-tools-video-compress
description: When the user asks to compress a video, reduce file size, convert MOV to MP4, re-encode video, or change video codec — activate this skill for ffmpeg-based video compression and format conversion
---

# Video Compress & Convert Skill

## Current Context

ffmpeg availability:
`!ffmpeg -version 2>/dev/null | head -1 || echo "ffmpeg not installed — brew install ffmpeg"`

Compress and convert individual video files using ffmpeg with multiple encoder options (H.265, H.264, AV1, VP9).

## Goal

Take a single input video file and produce a compressed version in the desired format, optimizing for the best balance of file size, quality, and compatibility based on the user's needs.

## Constraints

- Requires `ffmpeg` and `ffprobe` — if missing, tell user to install via `brew install ffmpeg`
- Never overwrite the input file — always write to a new output path
- Always verify output with `ffprobe` before reporting success
- Quote all file paths to handle spaces
- Warn the user before starting AV1 encodes (they are very slow)

## Encoder Reference

| Encoder | ffmpeg flag | Best For | Compression | Speed | Compatibility |
|---------|------------|----------|-------------|-------|---------------|
| H.265/HEVC | `libx265` | General use (default) | Excellent | Medium | macOS, iOS, most players |
| H.264/AVC | `libx264` | Max compatibility | Good | Fast | Everything |
| AV1 | `libsvtav1` | Smallest possible file | Best | Slow | Chrome, Firefox, VLC |
| VP9 | `libvpx-vp9` | WebM for web | Very good | Slow | Browsers, VLC |

### When to Pick Each Encoder

- **H.265**: Default choice. Best balance of size, quality, and compatibility
- **H.264**: When the video must play everywhere (older devices, embedded players, legacy systems)
- **AV1**: When smallest file size matters more than encode time (archival, bandwidth-constrained sharing)
- **VP9**: When output must be WebM (web embedding, browser-only playback)

## Quality Presets

| Preset | CRF (H.265) | CRF (H.264) | Max Width | Typical Reduction |
|--------|-------------|-------------|-----------|-------------------|
| `lossless` | 0 | 0 | original | 0% (larger) |
| `high` | 23 | 19 | original | 60-75% |
| `balanced` | 28 | 23 | 1920 | 85-93% |
| `small` | 32 | 27 | 1280 | 93-97% |
| `tiny` | 36 | 31 | 854 | 97-99% |

## Process

### 1. Probe Source
- Run `ffprobe` to get codec, resolution, fps, bitrate, duration, size
- Identify optimization opportunities (high fps, Retina resolution, inefficient codec)
- Present source summary table

### 2. Recommend Settings
- Pick encoder based on user request or default to H.265
- Pick quality preset based on user request or default to balanced
- Apply smart defaults:
  - Normalize fps > 30 to 30fps (unless gaming/slow-mo content)
  - Scale down Retina resolutions for balanced/small/tiny presets
  - Compress audio to AAC 128k (or Opus for WebM/AV1)

### 3. Encode
- Run ffmpeg with chosen parameters
- Always include `-movflags +faststart` for MP4 (enables web streaming)
- Always include `-tag:v hvc1` for H.265 (Apple compatibility)
- Use appropriate audio codec: AAC for MP4, Opus for WebM

### 4. Report
- Show before/after comparison table
- Report compression ratio and reduction percentage
- Suggest quality verification and offer to re-encode if needed

## Format Conversion Notes

- **MOV to MP4** (same codec): Use `-c copy` for instant conversion — no quality loss, no size change
- **MOV to MP4** (with compression): Re-encode with H.265 for major size reduction
- **Any to WebM**: Must use VP9 or AV1 video codec, Opus audio
- **Container vs Codec**: Changing container (MOV/MP4/MKV) doesn't reduce size — codec and bitrate do

## Gotchas

- **Screen recordings** (QuickTime, OBS) waste space with 120fps timebase — normalizing to 30fps saves 50%+
- **`-c copy` misconception**: Users often think converting MOV to MP4 will compress it — explain that `-c copy` only changes the container
- **libx265 availability**: Not all ffmpeg builds include it. Check with `ffmpeg -encoders | grep libx265`
- **macOS H.265**: Without `-tag:v hvc1`, Finder and QuickTime won't play the file
- **AV1 time**: Encoding is 5-10x slower than H.265 — always warn before starting
- **Hardware vs software**: `hevc_videotoolbox` (Apple Silicon) is faster but `libx265` gives better compression — prefer software for best results
- **Audio-only streams**: Some screen recordings have no audio — use `-an` flag or ffmpeg will error on audio codec settings
