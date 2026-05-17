---
name: cf-tools-video-speed
description: "Speed up or slow down a video, preserving audio pitch via atempo. Trigger: /cf-tools-video-speed"
trigger: /cf-tools-video-speed
version: 1.0.0
---

# /cf-tools-video-speed

Change playback rate. Video uses `setpts` (presentation timestamps); audio uses `atempo` so voice/music don't chipmunk or droop. Multiple `atempo` filters are chained automatically because `atempo` only accepts 0.5–2.0 per pass.

Related skills:
- `/cf-tools-video-trim` — pre-cut before speed change
- `/cf-tools-video-mute` — drop audio if you don't care about pitch

## Usage

```
/cf-tools-video-speed input.mp4 --rate 2          # 2× faster
/cf-tools-video-speed input.mp4 --rate 0.5        # half-speed slow-mo
/cf-tools-video-speed input.mp4 --rate 4 --output fast.mp4
/cf-tools-video-speed input.mp4 --rate 0.25       # 4× slower (chained atempo)
```

Arguments:
1. `input` (required)
2. `--rate FLOAT` (required, 0.1 – 100) — playback multiplier
3. `--output PATH` (default `<stem>-x<rate>.mp4`)

## What You Must Do When Invoked

### Step 1 — Compute setpts and atempo chain

```bash
RATE="$1"             # e.g. 2 → 0.5×PTS;   0.25 → 4×PTS
PTS=$(python3 -c "print(1/$RATE)")
# Build atempo chain — each filter clamped to [0.5, 2.0].
build_atempo() {
  local r="$1" out=""
  python3 - "$r" <<'PY'
import sys
r=float(sys.argv[1]); parts=[]
while r>2.0: parts.append("atempo=2.0"); r/=2.0
while r<0.5: parts.append("atempo=0.5"); r/=0.5
parts.append(f"atempo={r:.6f}")
print(",".join(parts))
PY
}
ATEMPO=$(build_atempo "$RATE")
```

### Step 2 — Encode

```bash
ffmpeg -y -i "$INPUT" \
  -filter_complex "[0:v]setpts=${PTS}*PTS[v];[0:a]${ATEMPO}[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset medium -crf 23 \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  "$OUTPUT"
```

If the input has no audio, drop the `[a]` map and the `[0:a]` filter chain.

### Step 3 — Verify

```bash
IN_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT")
OUT_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT")
echo "Input: ${IN_DUR}s → Output: ${OUT_DUR}s (expected ~$(python3 -c "print($IN_DUR/$RATE)")s)"
```

## Output Contract

```
## Video speed

**Source:**   <input>   (<in-duration>s)
**Rate:**     <N>×
**Output:**   <output>  (<out-duration>s)
**Audio:**    pitch-preserved via atempo chain (N stages)
```

## Gotchas

- `atempo` clamps to [0.5, 2.0] per filter. Anything outside requires chaining (handled above). Without the chain, ffmpeg silently clips and audio drifts out of sync.
- `setpts` doesn't drop frames — extremely high speeds (`--rate 50`) yield jittery output. Combine with `fps=30` filter for smooth fast-motion: `setpts=${PTS}*PTS,fps=30`.
- Slow-motion below 0.25× loses crispness because real frames are duplicated. Source must be high-fps (60/120) for clean slow-mo.
- Subtitle streams aren't re-timed automatically — strip them or use `-c:s mov_text` and apply manual delays.

## Cross-Platform Notes

`python3` is used for arithmetic to avoid `bc` portability issues. Works on macOS, Linux, Windows (any Python 3 install). Apple Silicon: substitute `-c:v h264_videotoolbox` for faster encode when CRF quality control isn't critical.
