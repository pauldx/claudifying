---
name: cf-tools-video-watermark
description: "Overlay a PNG logo or text watermark on a video at a chosen corner. Trigger: /cf-tools-video-watermark"
trigger: /cf-tools-video-watermark
version: 1.0.0
---

# /cf-tools-video-watermark

Burn a watermark into a video. Supports either an image overlay (PNG with alpha — recommended) or a text overlay rendered with ffmpeg's `drawtext` filter. Watermark position is one of `tl`, `tr`, `bl`, `br`, `center`.

Related skills:
- `/cf-tools-image-convert-svg-png` — produce a retina PNG logo first
- `/cf-tools-video-resize` — resize before watermarking for consistent logo scaling

## Usage

```
/cf-tools-video-watermark input.mp4 --image logo.png --position br
/cf-tools-video-watermark input.mp4 --image logo.png --position tl --margin 20 --opacity 0.6
/cf-tools-video-watermark input.mp4 --text "Sample" --position br
/cf-tools-video-watermark input.mp4 --text "© 2026" --position br --font-size 32 --color white@0.8
```

Arguments:
1. `input` (required)
2. `--image PATH` OR `--text STRING` (one required)
3. `--position tl|tr|bl|br|center` (default `br`)
4. `--margin N` (default 20) — pixels from edge
5. `--opacity 0.0–1.0` (default 1.0) — image mode only
6. `--font-size N` (default 28) — text mode only
7. `--color WORD[@alpha]` (default `white@0.85`) — text mode
8. `--output PATH` (default `<stem>-wm.mp4`)

## What You Must Do When Invoked

### Step 1 — Resolve position coordinates

| `--position` | x | y |
|---|---|---|
| `tl` | `M` | `M` |
| `tr` | `W-w-M` | `M` |
| `bl` | `M` | `H-h-M` |
| `br` | `W-w-M` | `H-h-M` |
| `center` | `(W-w)/2` | `(H-h)/2` |

Where `W,H` = main video dims, `w,h` = overlay dims, `M` = margin.

### Step 2a — Image watermark

```bash
# Pre-process alpha for opacity (ffmpeg overlay doesn't have global opacity)
ffmpeg -y -i "$INPUT" -i "$LOGO" -filter_complex "
  [1:v]format=rgba,colorchannelmixer=aa=${OPACITY}[wm];
  [0:v][wm]overlay=${X}:${Y}
" -c:v libx264 -preset medium -crf 23 -c:a copy -movflags +faststart "$OUTPUT"
```

### Step 2b — Text watermark

```bash
# Locate a default font; fall back if not present
FONT="/System/Library/Fonts/Helvetica.ttc"  # macOS default
[ ! -f "$FONT" ] && FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
[ ! -f "$FONT" ] && FONT=""   # let ffmpeg pick system default

ffmpeg -y -i "$INPUT" -vf "
  drawtext=fontfile='${FONT}':text='${TEXT}':fontsize=${FONT_SIZE}:
  fontcolor=${COLOR}:x=${X_TEXT}:y=${Y_TEXT}:
  box=1:boxcolor=black@0.3:boxborderw=8
" -c:v libx264 -preset medium -crf 23 -c:a copy -movflags +faststart "$OUTPUT"
```

For text mode, `w` and `h` are replaced by `text_w` / `text_h` in the position expressions.

### Step 3 — Verify

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration -of default=nw=1 "$OUTPUT"
```

## Output Contract

```
## Video watermark

**Source:**     <input>
**Watermark:**  image=<path> | text="<str>"
**Position:**   <tl|tr|bl|br|center>  (margin <Npx>)
**Opacity:**    <0–1>  (image mode)
**Output:**     <output>
**Verified:**   dimensions + duration match source
```

## Gotchas

- `overlay` filter has no global opacity option. Use `colorchannelmixer=aa=` on the watermark stream before overlaying (handled above).
- `drawtext` requires libfreetype + libharfbuzz built into ffmpeg. Many distributions (including default macOS Homebrew bottles as of 2026) ship WITHOUT it. Test once with `ffmpeg -filters | grep drawtext` — if empty, fall back to image mode using `/cf-tools-image-convert-svg-png` to rasterize text first, then overlay as PNG. Reinstall with `brew install ffmpeg --with-freetype` only on builds from source.
- Don't escape single quotes in text yourself — pass as bash-quoted string. For colons in text use `\:`.
- Large logos can dominate small videos. Recommend logos ≤ 15% of main video width — pre-resize with `--image` step (`scale=W*0.15:-1`).
- The output is fully transcoded video (CRF 23). Pair with `/cf-tools-video-compress` for tighter bitrate after.

## Cross-Platform Notes

Font paths differ:
- **macOS**: `/System/Library/Fonts/Helvetica.ttc`
- **Linux**: `/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf`
- **Windows**: `C:/Windows/Fonts/arial.ttf`

The skill probes each and falls back. If none found, ffmpeg uses its built-in default which may render boxy glyphs.
