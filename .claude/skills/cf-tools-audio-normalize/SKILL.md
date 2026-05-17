---
name: cf-tools-audio-normalize
description: "Loudness-normalize audio to broadcast standard (EBU R128, -16 LUFS) via ffmpeg loudnorm. Trigger: /cf-tools-audio-normalize"
trigger: /cf-tools-audio-normalize
version: 1.0.0
---

# /cf-tools-audio-normalize

Normalize perceived loudness to the EBU R128 standard. Default target is -16 LUFS (web/podcast standard); switch to -23 LUFS for broadcast or -14 LUFS for streaming services.

## Usage

```
/cf-tools-audio-normalize input.mp3 output.mp3
/cf-tools-audio-normalize input.wav output.wav --target -23
/cf-tools-audio-normalize input.mp3 output.mp3 --target -14 --tp -1.5
/cf-tools-audio-normalize input.mp3 output.mp3 --two-pass
```

Arguments:
1. `input` (required)
2. `output` (required)
3. `--target <LUFS>` (optional, default `-16`) — integrated loudness target
4. `--tp <dBTP>` (optional, default `-1.5`) — true-peak ceiling
5. `--lra <LU>` (optional, default `11`) — loudness range
6. `--two-pass` (optional flag) — measure first, then apply (best accuracy)

## Why R128 / LUFS

Peak normalization (e.g. ReplayGain in the old days) ignores perceived loudness. Two tracks both peaking at 0 dBFS can sound 6 LU apart. R128 measures the integrated loudness curve over the whole file and applies a single gain so the **perceived** level matches across content.

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; OUTPUT="$2"; shift 2
TARGET="-16"; TP="-1.5"; LRA="11"; TWO_PASS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --tp) TP="$2"; shift 2 ;;
    --lra) LRA="$2"; shift 2 ;;
    --two-pass) TWO_PASS=1; shift ;;
    *) shift ;;
  esac
done
```

### Step 2 — Pick output codec

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

### Step 3a — One-pass (faster, slightly less accurate)

```bash
if [ "$TWO_PASS" -eq 0 ]; then
  ffmpeg -y -i "$INPUT" \
    -af "loudnorm=I=${TARGET}:TP=${TP}:LRA=${LRA}" \
    -c:a $CODEC "$OUTPUT"
fi
```

### Step 3b — Two-pass (recommended for final renders)

```bash
if [ "$TWO_PASS" -eq 1 ]; then
  STATS=$(ffmpeg -hide_banner -i "$INPUT" \
    -af "loudnorm=I=${TARGET}:TP=${TP}:LRA=${LRA}:print_format=json" \
    -f null - 2>&1 | sed -n '/{/,/}/p')

  M_I=$(echo "$STATS"     | grep input_i        | awk -F'"' '{print $4}')
  M_TP=$(echo "$STATS"    | grep input_tp       | awk -F'"' '{print $4}')
  M_LRA=$(echo "$STATS"   | grep input_lra      | awk -F'"' '{print $4}')
  M_THRESH=$(echo "$STATS"| grep input_thresh   | awk -F'"' '{print $4}')
  T_OFFSET=$(echo "$STATS"| grep target_offset  | awk -F'"' '{print $4}')

  ffmpeg -y -i "$INPUT" \
    -af "loudnorm=I=${TARGET}:TP=${TP}:LRA=${LRA}:measured_I=${M_I}:measured_TP=${M_TP}:measured_LRA=${M_LRA}:measured_thresh=${M_THRESH}:offset=${T_OFFSET}:linear=true:print_format=summary" \
    -c:a $CODEC "$OUTPUT"
fi
```

### Step 4 — Verify

```bash
ffmpeg -hide_banner -i "$OUTPUT" -af loudnorm=print_format=summary -f null - 2>&1 | grep -E "Input Integrated|Input True Peak"
```

## Output Contract

```
## Audio normalize (EBU R128)

**Source:**       <input>
**Output:**       <output>
**Target:**       <LUFS> integrated, <dBTP> true-peak ceiling, <LU> LRA
**Mode:**         one-pass | two-pass
**Measured I:**   <LUFS> (input)
**Measured TP:**  <dBTP> (input)
```

## Reference Loudness Targets

| Platform        | Integrated | True-peak | Notes |
|-----------------|------------|-----------|-------|
| YouTube         | -14 LUFS   | -1 dBTP   | streaming default |
| Spotify         | -14 LUFS   | -1 dBTP   | |
| Apple Music     | -16 LUFS   | -1 dBTP   | "Sound Check" reference |
| Podcasts (web)  | -16 LUFS   | -1 dBTP   | most podcast hosts |
| Broadcast (EBU) | -23 LUFS   | -1 dBTP   | TV / radio |
| Netflix         | -27 LUFS   | -2 dBTP   | dialogue-anchored |

## Gotchas

- **One-pass is non-linear**: loudnorm in single-pass mode uses dynamic gain riding. For mastering or critical work always use `--two-pass`.
- **Don't normalize an already-normalized file**: the algorithm assumes natural dynamics. Double-normalization causes loudness drift.
- **Clipping after normalize**: if you target -14 with TP=0, transients can still saturate. Keep TP ≤ -1 dBTP.
- **Mono files**: loudnorm works but reports slightly different from stereo. Convert to stereo first if mixing into a stereo program.
- **Very short clips**: integrated LUFS requires ≥ ~3 s. For shorter sources use peak normalize (`-af "volume=…"`) instead.

## Cross-Platform Notes

loudnorm filter ships with ffmpeg ≥ 3.1. macOS Homebrew, Linux apt, Windows builds all include it.
