---
name: cf-tools-audio-fade
description: "Apply fade-in and/or fade-out to an audio file via ffmpeg afade filter. Trigger: /cf-tools-audio-fade"
trigger: /cf-tools-audio-fade
version: 1.0.0
---

# /cf-tools-audio-fade

Smooth fade-in at the start, fade-out at the end, or both. Defaults to a 2-second fade on each side. Choose linear, exponential, or logarithmic curves.

## Usage

```
/cf-tools-audio-fade input.mp3 output.mp3                         # 2s fade both ends
/cf-tools-audio-fade input.mp3 output.mp3 --in 3                  # 3s fade in only
/cf-tools-audio-fade input.mp3 output.mp3 --out 5                 # 5s fade out only
/cf-tools-audio-fade input.mp3 output.mp3 --in 1 --out 4
/cf-tools-audio-fade input.mp3 output.mp3 --in 2 --out 2 --curve esin
```

Arguments:
1. `input` (required)
2. `output` (required)
3. `--in <seconds>` (optional, default `2`) — fade-in duration; `0` = none
4. `--out <seconds>` (optional, default `2`) — fade-out duration; `0` = none
5. `--curve <type>` (optional, default `tri` = linear)

## Curve Types (afade `curve=` param)

| Curve   | Shape                       | Use case |
|---------|-----------------------------|----------|
| `tri`   | linear (triangular)         | default, generic |
| `qsin`  | quarter sine (smooth)       | natural music fades |
| `hsin`  | half sine                   | gentler |
| `esin`  | exponential sine            | dramatic fade-in |
| `log`   | logarithmic                 | quick start, slow tail |
| `ipar`  | inverted parabola           | bell-shaped |
| `qua`   | quadratic                   | smooth acceleration |
| `cub`   | cubic                       | smooth, more pronounced |

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; OUTPUT="$2"; shift 2
IN_DUR="2"; OUT_DUR="2"; CURVE="tri"
while [ $# -gt 0 ]; do
  case "$1" in
    --in) IN_DUR="$2"; shift 2 ;;
    --out) OUT_DUR="$2"; shift 2 ;;
    --curve) CURVE="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -f "$INPUT" ] || { echo "ERROR: input not found"; exit 1; }
```

### Step 2 — Probe duration (needed for fade-out start time)

```bash
DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")
[ -n "$DUR" ] || { echo "ERROR: could not read duration"; exit 1; }
```

### Step 3 — Build filter chain

```bash
FILTERS=()
if [ "$(echo "$IN_DUR > 0" | bc)" -eq 1 ]; then
  FILTERS+=("afade=t=in:st=0:d=${IN_DUR}:curve=${CURVE}")
fi
if [ "$(echo "$OUT_DUR > 0" | bc)" -eq 1 ]; then
  START=$(echo "$DUR - $OUT_DUR" | bc -l)
  FILTERS+=("afade=t=out:st=${START}:d=${OUT_DUR}:curve=${CURVE}")
fi

if [ "${#FILTERS[@]}" -eq 0 ]; then
  echo "ERROR: both --in and --out are 0; nothing to do"
  exit 1
fi

FILTER_STR=$(IFS=,; echo "${FILTERS[*]}")
```

### Step 4 — Choose codec by output extension

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
ffmpeg -y -i "$INPUT" -af "$FILTER_STR" -c:a $CODEC "$OUTPUT"
```

### Step 6 — Verify

```bash
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT"
```

Optional spot-check via volume meter:

```bash
ffmpeg -hide_banner -i "$OUTPUT" -af "astats=metadata=1:reset=1" -f null - 2>&1 | grep -E "RMS level|Peak level" | head -4
```

## Output Contract

```
## Audio fade

**Source:**       <input>
**Output:**       <output>
**Duration:**     <s>s
**Fade-in:**      <IN_DUR>s (<curve>)
**Fade-out:**     <OUT_DUR>s (<curve>)
**Filter:**       <filter_str>
```

## Gotchas

- **Fade longer than file**: if `--out 10` on a 5-second clip, you'll get an inaudible result. Validate `IN_DUR + OUT_DUR < DUR`.
- **Cross-fade between two files**: this skill is single-file. For cross-fade, use `cf-tools-audio-merge` with the `acrossfade` filter (different filter).
- **Hard cut still audible after fade-out**: re-check `DUR - OUT_DUR` math — most often a rounding issue. Trim the file first with `cf-tools-audio-trim --accurate`.
- **Stereo phase issues**: afade is applied per channel independently; no phase risk.
- **`bc` not installed on minimal Linux containers**: replace with `awk 'BEGIN{print 5.2 - 2}'` fallback.

## Cross-Platform Notes

- afade is a core ffmpeg filter — available on all platforms with ffmpeg ≥ 3.0.
- `bc` ships by default on macOS and most Linux distros. Use `awk` fallback in BusyBox / Alpine images.
