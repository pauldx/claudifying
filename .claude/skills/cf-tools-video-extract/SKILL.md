---
name: cf-tools-video-extract
description: When the user asks to download a video, extract a video, save a video from x.com (Twitter), or grab a video from a tweet — activate this video extraction skill
---

# Video Extractor (x.com)

Download videos from x.com (Twitter) posts using `yt-dlp`.

## Activation

- "Download the video from this tweet"
- "Extract video from https://x.com/..."
- "Save this X video"
- "Grab the video from this post"
- "Download video from Twitter"

## Supported Platforms

- **x.com / twitter.com** — public posts with embedded video

> Future: extend to YouTube, Instagram, etc. by adding platform-specific handling.

## Process

### 1. Ensure yt-dlp Is Installed

```bash
which yt-dlp 2>/dev/null || brew install yt-dlp
```

If `brew` not available, suggest `pip install yt-dlp` or `pipx install yt-dlp`.

### 2. Normalize URL

X/Twitter URLs come in multiple forms. Normalize before passing to yt-dlp:

- `https://x.com/user/status/123456` — canonical
- `https://twitter.com/user/status/123456` — legacy, works fine
- `https://x.com/user/status/123456?s=48` — strip query params, yt-dlp handles them but cleaner without
- Mobile URLs (`https://mobile.twitter.com/...`) — also supported

### 3. List Available Formats

```bash
yt-dlp --list-formats "$URL" 2>&1
```

Inspect output to identify:
- **Video-only streams** (hls-* with "video only") — need audio merge
- **Pre-merged HTTP streams** (http-*) — contain both video + audio
- **Audio-only streams** — for audio extraction requests

X/Twitter typically provides:
| Format | Resolution | Type |
|--------|-----------|------|
| http-256 | 480x270 | pre-merged |
| http-832 | 640x360 | pre-merged |
| http-2176 | 1280x720 | pre-merged |
| http-10368 | 1920x1080 | pre-merged |

### 4. Download Video

**Best quality (default):**
```bash
yt-dlp -f "b" -o "$HOME/Downloads/%(title)s.%(ext)s" "$URL" 2>&1
```

Use `-f b` (not `-f best`) to suppress yt-dlp warning. This selects best pre-merged format.

**Let yt-dlp merge best video + audio (highest quality possible):**
```bash
yt-dlp -o "$HOME/Downloads/%(title)s.%(ext)s" "$URL" 2>&1
```

Requires `ffmpeg` for merging. Check: `which ffmpeg`.

**Specific resolution:**
```bash
# 720p
yt-dlp -f "http-2176" -o "$HOME/Downloads/%(title)s.%(ext)s" "$URL" 2>&1

# 360p (smaller file)
yt-dlp -f "http-832" -o "$HOME/Downloads/%(title)s.%(ext)s" "$URL" 2>&1
```

**Custom output path:**
```bash
yt-dlp -f "b" -o "/path/to/output/filename.%(ext)s" "$URL" 2>&1
```

### 5. Verify Download

```bash
# Check file exists and size
ls -lh "$OUTPUT_FILE"

# Get duration and codec info
ffprobe -v quiet -print_format json -show_format -show_streams "$OUTPUT_FILE" 2>&1 | \
  python3 -c "
import json, sys
d = json.load(sys.stdin)
fmt = d['format']
duration = float(fmt['duration']) / 60
print(f'Duration: {duration:.1f} min')
for s in d['streams']:
    kind = s['codec_type']
    codec = s.get('codec_name', '?')
    if kind == 'video':
        print(f'Video: {codec} {s.get(\"width\",\"?\")}x{s.get(\"height\",\"?\")}')
    elif kind == 'audio':
        print(f'Audio: {codec}')
"
```

Report duration, resolution, codec, and file size to user.

## Output

- Video file saved to `~/Downloads/` (or user-specified path)
- File metadata: duration, resolution, codec, size

## Gotchas

- **`-f best` triggers a warning** — use `-f b` for best pre-merged, or omit `-f` entirely for best merged (requires ffmpeg).
- **Private/protected tweets** — yt-dlp cannot access videos from private accounts. Will fail with authentication error.
- **Rate limiting** — X may throttle repeated downloads. Space out requests if downloading multiple videos.
- **Guest token extraction** — yt-dlp fetches a guest token automatically. If X changes their API, yt-dlp may need updating: `brew upgrade yt-dlp`.
- **Sandbox restrictions** — `~/Downloads` may be blocked by Claude Code sandbox. Use `$TMPDIR` as intermediate:
  ```bash
  yt-dlp -f "b" -o "$TMPDIR/video.%(ext)s" "$URL"
  cp "$TMPDIR/video.mp4" ~/Downloads/
  ```
- **No video in tweet** — some posts embed videos from external sites (YouTube, etc.). yt-dlp will follow the embed, but format IDs will differ from X-native videos.
- **Spaces in output filenames** — `%(title)s` can produce filenames with special characters. Use `--restrict-filenames` flag to sanitize:
  ```bash
  yt-dlp --restrict-filenames -f "b" -o "$HOME/Downloads/%(title)s.%(ext)s" "$URL"
  ```
- **Large videos (1080p+)** — pre-merged HTTP formats from X can be 1GB+. Check available space before downloading.
- **ffprobe not installed** — verification step needs ffmpeg/ffprobe. Install: `brew install ffmpeg`. Skip verification if not available — download still works.
