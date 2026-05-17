---
name: cf-tools-video-thumbnail
description: "Extract a single frame or NxN sprite-sheet thumbnail grid from a video. Trigger: /cf-tools-video-thumbnail"
trigger: /cf-tools-video-thumbnail
version: 1.0.0
---

# /cf-tools-video-thumbnail

Generate either a single still frame at a chosen timestamp or a grid sprite-sheet of evenly-spaced frames (great for video preview tiles / scrubbing strips).

Related skills:
- `/cf-tools-video-metadata` — find good timestamps first
- `/cf-tools-image-convert-svg-png` — for vector → raster

## Usage

```
/cf-tools-video-thumbnail input.mp4                              # single frame at midpoint
/cf-tools-video-thumbnail input.mp4 --time 00:00:03              # single frame at 3s
/cf-tools-video-thumbnail input.mp4 --time 3.5 --output thumb.jpg
/cf-tools-video-thumbnail input.mp4 --grid 3x3                   # 9-tile sprite sheet
/cf-tools-video-thumbnail input.mp4 --grid 4x2 --width 320       # custom tile size
```

Arguments:
1. `input` (required)
2. `--time HH:MM:SS | seconds` (default: 50% of duration) — single-frame mode
3. `--grid NxM` — sprite-sheet mode (overrides `--time`)
4. `--width N` (default 320) — tile width in pixels for grid mode
5. `--output PATH` (default `<stem>-thumb.jpg` or `<stem>-grid.jpg`)

## What You Must Do When Invoked

### Step 1 — Probe duration

```bash
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT")
```

### Step 2a — Single frame mode

```bash
TIME="${TIME:-$(echo "$DUR / 2" | bc -l)}"
ffmpeg -y -ss "$TIME" -i "$INPUT" -frames:v 1 -q:v 2 "$OUTPUT"
```

`-q:v 2` is high-quality JPEG. Use `.png` for lossless output (no `-q:v` needed).

### Step 2b — Grid sprite-sheet mode

```bash
COLS="${GRID_COLS}"; ROWS="${GRID_ROWS}"; W="${WIDTH:-320}"
TOTAL=$((COLS * ROWS))
# Sample at ROW*COLS evenly-spaced points; -vf select+tile builds the sheet.
INTERVAL=$(echo "$DUR / $TOTAL" | bc -l)

ffmpeg -y -i "$INPUT" \
  -vf "fps=1/${INTERVAL},scale=${W}:-1,tile=${COLS}x${ROWS}" \
  -frames:v 1 -q:v 2 "$OUTPUT"
```

### Step 3 — Verify

```bash
file "$OUTPUT"   # should be JPEG/PNG image
ffprobe -v error -show_entries stream=width,height -of csv=p=0 "$OUTPUT"
```

## Output Contract

```
## Video thumbnail

**Source:**   <input>
**Mode:**     single | grid (CxR = N tiles)
**Output:**   <output>
**Size:**     <WxH> px
**Time(s):**  <ts or interval>
```

## Gotchas

- `-ss` before `-i` is fast but can land on the nearest keyframe (frame may be a few hundred ms off). Put `-ss` after `-i` for exact-frame thumbnails (slower).
- `tile` filter requires consistent frame sizes — chain `scale` BEFORE `tile`.
- For very short videos with `--grid 4x4`, the interval may drop below the source frame rate, repeating frames. Reduce grid size.
- Use `.png` output for screenshots with text overlays to avoid JPEG artifacts.
- `bc` may not be available on minimal Alpine — substitute `python3 -c "print($DUR/2)"`.

## Cross-Platform Notes

Identical ffmpeg syntax across platforms. macOS/Linux `bc` is preinstalled; on Windows use `set /a` or PowerShell arithmetic. For batch web previews, prefer `.webp` output (`-c:v libwebp -lossless 0 -q:v 80`).
