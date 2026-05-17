---
name: cf-tools-video-join
description: When the user asks to merge videos, join clips, concatenate recordings, compress video, or convert to MP4 — activate this skill for ffmpeg-based video merging and compression
---

# Video Join & Compress Skill

## Current Context

ffmpeg availability:
`!ffmpeg -version 2>/dev/null | head -1 || echo "ffmpeg not installed — brew install ffmpeg"`

Merge multiple video files into a single optimized MP4 using ffmpeg concat demuxer and H.265 (HEVC) encoding.

## Goal

Take N input video files, concatenate them in order, and produce a single compressed MP4 that is significantly smaller than the combined inputs while maintaining acceptable visual quality.

## Constraints

- Requires `ffmpeg` and `ffprobe` on the system — if missing, tell the user to install via `brew install ffmpeg`
- Never overwrite input files — always write to a new output path
- Always clean up temporary files (concat lists) after completion
- Quote all file paths to handle spaces
- Always verify output with `ffprobe` before reporting success

## Encoding Strategy

Use H.265 (HEVC) via `libx265` for best compression. Key parameters:

| Parameter | Value | Why |
|-----------|-------|-----|
| `-c:v libx265` | HEVC codec | ~50% smaller than H.264 at same quality |
| `-crf 28` | Constant Rate Factor | Good balance of quality vs size (adjustable 23-32) |
| `-preset medium` | Encoding speed | Best speed/compression tradeoff |
| `-r 30` | Frame rate | Normalizes wasteful high-fps screen recordings |
| `-tag:v hvc1` | Container tag | Required for Apple/QuickTime playback |
| `-movflags +faststart` | Moov atom | Enables web streaming / fast preview |
| `-c:a aac -b:a 128k` | Audio | Good stereo quality, wide compatibility |

### Quality Presets

| Preset | CRF | Max Width | Use Case |
|--------|-----|-----------|----------|
| `high` | 23 | original | Presentation recordings, demos |
| `balanced` | 28 | 1920 | General purpose (default) |
| `small` | 32 | 1280 | Sharing via chat/email, quick reviews |

## Process

### 1. Validate
- Confirm ffmpeg is installed
- Verify all input files exist
- Probe each file for resolution, fps, codec, duration, size
- Present input summary table

### 2. Decide Encoding Path
- If all inputs share same resolution, codec, and fps — offer fast-path (stream copy, no re-encode) alongside compressed path
- If resolutions differ — must re-encode with scale filter to normalize
- If fps > 30 or variable — normalize to 30fps
- Map quality preset to CRF and scale values

### 3. Execute
- Write concat list to `/tmp/ffmpeg_concat_<timestamp>.txt`
- Run ffmpeg with appropriate flags
- Monitor for errors (missing codec, incompatible streams)

### 4. Report
- Show before/after comparison: format, resolution, duration, size, reduction %
- Suggest playing the output to verify quality
- Offer to re-encode with different CRF if quality is unsatisfactory

## Gotchas

- **Screen recordings** (QuickTime, OBS) report 120fps timebase but actual content is ~15fps — normalizing to 30fps saves 50%+ space alone
- **Mixed resolutions** break concat with `-c copy` — must re-encode with scale filter
- **libx265 missing**: Fall back to `libx264` with CRF +4 for comparable file sizes
- **macOS playback**: Without `-tag:v hvc1`, Finder/QuickTime won't play H.265 natively
- **Spaces in paths**: Always wrap paths in single quotes inside the concat list
- **Large encodes**: Can take several minutes for long videos — use `timeout` parameter on Bash calls
