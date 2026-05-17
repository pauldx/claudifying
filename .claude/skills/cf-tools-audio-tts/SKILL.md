---
name: cf-tools-audio-tts
description: "Generate speech from text via edge-tts — Microsoft Edge cloud voices, 270+ choices, no API key required. Trigger: /cf-tools-audio-tts"
trigger: /cf-tools-audio-tts
version: 1.0.0
---

# /cf-tools-audio-tts

Convert text to natural-sounding speech using Microsoft Edge's neural voices via the `edge-tts` Python CLI. No account, no API key — uses the same backend that powers Edge's Read-Aloud feature.

## Prerequisite

Already installed in this environment. To install elsewhere:

```bash
pipx install edge-tts
edge-tts --help
edge-tts --list-voices | head -20
```

## Usage

```
/cf-tools-audio-tts "Hello, world." output.mp3
/cf-tools-audio-tts --file script.txt output.mp3
/cf-tools-audio-tts "Bonjour le monde" output.mp3 --voice fr-FR-DeniseNeural
/cf-tools-audio-tts "Read fast." output.mp3 --rate "+30%"
/cf-tools-audio-tts "Whisper this." output.mp3 --voice en-US-AriaNeural --volume "-20%"
```

Arguments:
1. Either inline `"text"` OR `--file <path>` (required) — the script to speak
2. `output` (required) — `.mp3` path
3. `--voice <name>` (optional, default `en-US-AriaNeural`) — see voice catalog below
4. `--rate <±N%>` (optional, default `+0%`) — speed up/slow down (-50% to +100%)
5. `--volume <±N%>` (optional, default `+0%`) — loudness adjust
6. `--pitch <±NHz>` (optional, default `+0Hz`) — pitch shift

## Popular Voices

**English (US)**
- `en-US-AriaNeural` — friendly, default
- `en-US-GuyNeural` — male, professional
- `en-US-JennyNeural` — warm, narrator
- `en-US-ChristopherNeural` — deep male
- `en-US-EmmaNeural` — clear female
- `en-US-AndrewNeural` — relaxed male (newer multilingual)
- `en-US-AvaNeural` — natural female (newer multilingual)

**English (UK)**
- `en-GB-SoniaNeural` — British female
- `en-GB-RyanNeural` — British male
- `en-GB-LibbyNeural` — younger British female

**English (other)**
- `en-AU-NatashaNeural` / `en-AU-WilliamNeural` — Australian
- `en-IN-NeerjaNeural` / `en-IN-PrabhatNeural` — Indian English

**Other languages (sample)**
- `es-ES-ElviraNeural` — Spanish (Spain)
- `es-MX-DaliaNeural` — Spanish (Mexico)
- `fr-FR-DeniseNeural` / `fr-FR-HenriNeural` — French
- `de-DE-KatjaNeural` / `de-DE-ConradNeural` — German
- `it-IT-ElsaNeural` — Italian
- `ja-JP-NanamiNeural` / `ja-JP-KeitaNeural` — Japanese
- `zh-CN-XiaoxiaoNeural` / `zh-CN-YunxiNeural` — Mandarin
- `hi-IN-SwaraNeural` / `hi-IN-MadhurNeural` — Hindi
- `pt-BR-FranciscaNeural` — Portuguese (Brazil)

Run `edge-tts --list-voices` for the full 270+ catalog.

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
TEXT=""; FILE=""; OUTPUT=""
VOICE="en-US-AriaNeural"; RATE="+0%"; VOLUME="+0%"; PITCH="+0Hz"

while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="$2"; shift 2 ;;
    --voice) VOICE="$2"; shift 2 ;;
    --rate) RATE="$2"; shift 2 ;;
    --volume) VOLUME="$2"; shift 2 ;;
    --pitch) PITCH="$2"; shift 2 ;;
    *)
      if [ -z "$TEXT" ] && [ -z "$FILE" ] && [ "${1:0:2}" != "--" ]; then
        TEXT="$1"
      elif [ -z "$OUTPUT" ]; then
        OUTPUT="$1"
      fi
      shift ;;
  esac
done

[ -n "$OUTPUT" ] || { echo "ERROR: output path required"; exit 1; }
```

### Step 2 — Build edge-tts invocation

```bash
ARGS=(--voice "$VOICE" --rate "$RATE" --volume "$VOLUME" --pitch "$PITCH" --write-media "$OUTPUT")
if [ -n "$FILE" ]; then
  ARGS+=(--file "$FILE")
else
  ARGS+=(--text "$TEXT")
fi

edge-tts "${ARGS[@]}"
```

### Step 3 — Optional: also write SRT timing

```bash
# Add --write-subtitles to the same call for sentence-level SRT:
edge-tts --voice "$VOICE" --text "$TEXT" \
  --write-media "$OUTPUT" \
  --write-subtitles "${OUTPUT%.mp3}.srt"
```

### Step 4 — Verify

```bash
ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name -of default=noprint_wrappers=1 "$OUTPUT"
[ -s "$OUTPUT" ] || { echo "ERROR: empty output"; exit 1; }
```

## Output Contract

```
## Audio TTS

**Voice:**     <voice>
**Rate:**      <rate>
**Output:**    <output>
**Duration:**  <s>s
**Size:**      <KB>
**Word count:** <N>
```

## Gotchas

- **Internet required**: edge-tts calls Microsoft's cloud endpoint. Offline = fail. For offline TTS use `piper` or `coqui-tts`.
- **Rate/pitch SSML format**: percentages need the sign (`+30%`, not `30%`). Hz for pitch (`+50Hz`).
- **Long scripts**: chunks > ~10,000 chars sometimes time out. Split the file and merge with `cf-tools-audio-merge`.
- **No SSML in `--text`**: angle brackets in the text are interpreted as SSML. Escape `<` and `>` or use `--file` with a plain text script.
- **Voices change**: Microsoft adds/removes voices periodically. Run `edge-tts --list-voices` to refresh.
- **Output is mp3 mono 24 kHz**: re-encode with `cf-tools-audio-convert` if you need stereo / higher rate.

## Cross-Platform Notes

Pure-Python tool. Works on macOS, Linux, Windows identically. Only requires Python 3.8+ and internet.
