---
name: cf-tools-video-loop
description: "Repeat a video N times via the concat demuxer for fast, lossless looping. Trigger: /cf-tools-video-loop"
trigger: /cf-tools-video-loop
version: 1.0.0
---

# /cf-tools-video-loop

Repeat a video file N times end-to-end. Uses ffmpeg's `concat` demuxer with `-c copy` for zero re-encode loss and near-instant runtime on any file size.

Related skills:
- `/cf-tools-video-join` — concatenate different clips
- `/cf-tools-video-trim` — cut before looping

## Usage

```
/cf-tools-video-loop input.mp4 --count 3
/cf-tools-video-loop input.mp4 --count 5 --output looped.mp4
/cf-tools-video-loop input.mp4 --count 10 --reencode   # for mismatched timestamps
```

Arguments:
1. `input` (required)
2. `--count N` (required, integer ≥ 2) — total number of plays (count=3 means 3 plays back-to-back)
3. `--output PATH` (default `<stem>-loop<N>.mp4`)
4. `--reencode` (optional) — re-encode instead of stream-copy if concat fails

## What You Must Do When Invoked

### Step 1 — Build concat list

```bash
LIST="$(mktemp -t loop-list.XXXXX.txt)"
INPUT_ABS="$(cd "$(dirname "$INPUT")" && pwd)/$(basename "$INPUT")"
for i in $(seq 1 "$COUNT"); do
  printf "file '%s'\n" "$INPUT_ABS" >> "$LIST"
done
```

The concat demuxer requires absolute paths (or paths relative to the list file) and one `file '...'` line per concatenation.

### Step 2a — Stream-copy concat (default)

```bash
ffmpeg -y -f concat -safe 0 -i "$LIST" -c copy -movflags +faststart "$OUTPUT"
```

`-safe 0` allows absolute paths in the list.

### Step 2b — Re-encode concat (fallback)

If stream-copy fails (timestamp gaps, codec parameter mismatches between same-source iterations are rare but happen in MKVs):

```bash
ffmpeg -y -f concat -safe 0 -i "$LIST" \
  -c:v libx264 -preset medium -crf 23 \
  -c:a aac -b:a 128k \
  -movflags +faststart "$OUTPUT"
```

### Step 3 — Verify

```bash
IN_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT")
OUT_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT")
EXPECTED=$(python3 -c "print($IN_DUR * $COUNT)")
echo "Source: ${IN_DUR}s × ${COUNT} → ${OUT_DUR}s (expected ~${EXPECTED}s)"
rm -f "$LIST"
```

## Output Contract

```
## Video loop

**Source:**     <input>     (<in-duration>s)
**Iterations:** <N>
**Output:**     <output>    (<out-duration>s)
**Method:**     stream-copy | re-encode
```

## Gotchas

- Some MP4 files have non-monotonic timestamps after concat. If players show frozen frames or audio drift, retry with `--reencode`.
- `concat` demuxer ≠ `concat` filter. The demuxer (used here) does not re-encode; the filter does.
- The list file must use forward slashes even on Windows. Wrap paths in single quotes.
- Looping a clip with no audio works fine; ffmpeg handles missing streams.
- `count=1` is a no-op (single play). The skill should reject `< 2`.

## Cross-Platform Notes

`mktemp -t` differs subtly between macOS (BSD) and Linux (GNU); the template `loop-list.XXXXX.txt` works on both. On Windows / WSL use Linux behavior. The concat demuxer is portable to all ffmpeg builds ≥ 3.0.
