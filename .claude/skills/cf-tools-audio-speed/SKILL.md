---
name: cf-tools-audio-speed
description: "Change audio playback speed without pitch shift via ffmpeg atempo filter (auto-chains for extreme ratios). Trigger: /cf-tools-audio-speed"
trigger: /cf-tools-audio-speed
version: 1.0.0
---

# /cf-tools-audio-speed

Speed up or slow down audio while preserving pitch. ffmpeg's `atempo` filter only accepts 0.5–2.0 per stage, so this skill auto-chains multiple stages for extreme ratios (e.g. 4× = `atempo=2.0,atempo=2.0`).

## Usage

```
/cf-tools-audio-speed input.mp3 output.mp3 1.5         # 1.5× faster
/cf-tools-audio-speed input.mp3 output.mp3 0.75        # 75% speed (slower)
/cf-tools-audio-speed input.mp3 output.mp3 3           # 3× faster (auto-chains)
/cf-tools-audio-speed input.mp3 output.mp3 0.4         # 0.4× (auto-chains)
/cf-tools-audio-speed input.mp3 output.mp3 1.5 --pitch # speed AND pitch shift (no atempo)
```

Arguments:
1. `input` (required)
2. `output` (required)
3. `ratio` (required) — playback speed multiplier; `> 1` = faster, `< 1` = slower
4. `--pitch` (optional flag) — change pitch with speed (rsample, no atempo); useful for chipmunk / drone effects

## Why atempo Chaining

`atempo` is a time-stretch algorithm (preserves pitch). It's stable in 0.5 – 2.0 range only. For ratios outside that:

| Target ratio | Filter chain |
|--------------|--------------|
| 0.5–2.0      | `atempo=R` |
| 2.0–4.0      | `atempo=2.0,atempo=R/2` |
| 4.0–8.0      | `atempo=2.0,atempo=2.0,atempo=R/4` |
| 0.25–0.5     | `atempo=0.5,atempo=R/0.5` |
| 0.125–0.25   | `atempo=0.5,atempo=0.5,atempo=R/0.25` |

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; OUTPUT="$2"; RATIO="$3"; shift 3
PITCH=0
[ "$1" = "--pitch" ] && PITCH=1

[ -f "$INPUT" ] || { echo "ERROR: input not found"; exit 1; }
[ -n "$RATIO" ] || { echo "ERROR: ratio required"; exit 1; }
```

### Step 2 — Build atempo chain (pitch-preserving)

```bash
build_chain() {
  python3 - "$1" <<'PY'
import sys
r = float(sys.argv[1])
if r <= 0:
    print("ERROR", file=sys.stderr); sys.exit(1)
parts = []
# Halve until <= 2.0
while r > 2.0:
    parts.append("atempo=2.0")
    r /= 2.0
# Double until >= 0.5
while r < 0.5:
    parts.append("atempo=0.5")
    r /= 0.5
parts.append(f"atempo={r:.6f}")
print(",".join(parts))
PY
}
```

### Step 3 — Pitch-shifting path (asetrate trick)

If `--pitch` flag set, resample then play at original rate — chipmunk / slow-deep effect.

```bash
build_pitch_chain() {
  RATIO="$1"
  # asetrate=SR*ratio,aresample=SR,atempo=1
  SR=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT")
  NEW_SR=$(python3 -c "print(int($SR * $RATIO))")
  echo "asetrate=${NEW_SR},aresample=${SR}"
}
```

### Step 4 — Pick codec

```bash
EXT="${OUTPUT##*.}"
case "$EXT" in
  mp3) CODEC="libmp3lame -b:a 192k" ;;
  aac|m4a) CODEC="aac -b:a 192k" ;;
  wav) CODEC="pcm_s16le" ;;
  flac) CODEC="flac" ;;
  opus) CODEC="libopus -b:a 96k" ;;
  *) CODEC="libmp3lame -b:a 192k" ;;
esac
```

### Step 5 — Apply

```bash
if [ "$PITCH" -eq 1 ]; then
  FILTER=$(build_pitch_chain "$RATIO")
else
  FILTER=$(build_chain "$RATIO")
fi

ffmpeg -y -i "$INPUT" -af "$FILTER" -c:a $CODEC "$OUTPUT"
```

### Step 6 — Verify

```bash
DUR_IN=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")
DUR_OUT=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT")
echo "Source ${DUR_IN}s → output ${DUR_OUT}s (ratio ${RATIO})"
```

## Output Contract

```
## Audio speed

**Source:**     <input>
**Output:**     <output>
**Ratio:**      <ratio>×
**Mode:**       pitch-preserving (atempo) | pitch-shifting (asetrate)
**Filter:**     <filter_str>
**Source dur:** <s>s
**Output dur:** <s>s (≈ source / ratio)
```

## Gotchas

- **Artifacts at extreme ratios**: 4× and beyond start sounding metallic even with chained atempo. For podcast 2× speed-listening, single `atempo=2.0` is clean.
- **Sub-0.5 chaining halves quality**: 0.25× stretches twice, each pass adds smearing. Use a dedicated tool (rubberband) for music.
- **rubberband alternative**: install `brew install rubberband`, then `ffmpeg -af "rubberband=tempo=1.5"` — higher fidelity but slower.
- **Pitch mode breaks duration prediction**: with `--pitch`, output duration = source/ratio AND pitch changes. Without `--pitch`, only duration changes.
- **Don't mix --pitch with atempo**: pick one mode.

## Cross-Platform Notes

atempo is core ffmpeg, no special build flags required. rubberband requires `ffmpeg --enable-librubberband` at compile time (Homebrew default in `ffmpeg` formula since 2023).
