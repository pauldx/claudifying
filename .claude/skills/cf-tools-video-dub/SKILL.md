---
name: cf-tools-video-dub
description: When the user asks to dub a video, re-voice a video, replace narration, change the voice in a video, translate video audio, or generate a voiceover — activate this skill for AI-powered video dubbing using Whisper + Edge TTS
---

# Video Dubbing Skill

Re-voice any video with a natural AI narrator using Whisper transcription and Edge TTS synthesis.

## Goal

Take an input video, extract the transcript, clean it up, generate a new voiceover with a consistent AI voice, and produce a dubbed video with the new audio track perfectly matched to the original duration.

## Prerequisites

### Required System Tools
- `ffmpeg` and `ffprobe` — install via `brew install ffmpeg`

### Required Python Environment
A Python 3.10+ virtual environment with these packages:
```bash
pip install openai-whisper edge-tts pydub soundfile numpy
```

If the project has a `.venv` directory, use it. Otherwise create one:
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install openai-whisper edge-tts pydub soundfile numpy
```

### Activation
Always activate the venv before running any Python:
```bash
source .venv/bin/activate
```

## Constraints

- Never overwrite the input video — always write to a new output path
- Always verify output with `ffprobe` before reporting success
- Quote all file paths to handle spaces and Unicode characters
- macOS filenames often contain hidden Unicode (e.g. narrow no-break space before AM/PM) — use glob patterns to copy files: `cp /path/to/Screen*Recording*PM.mov /tmp/clean_name.mp4`
- Always copy input to `/tmp/` with a clean filename before processing

## Available Voices

Edge TTS provides free, high-quality Microsoft Neural voices. Key voices:

| Voice ID | Name | Gender | Locale | Best For |
|----------|------|--------|--------|----------|
| `en-US-AndrewNeural` | Andrew | Male | US English | Professional narration, demos |
| `en-US-AndrewMultilingualNeural` | Andrew Multilingual | Male | US English | Multi-language content |
| `en-US-GuyNeural` | Guy | Male | US English | Casual, friendly |
| `en-US-JennyNeural` | Jenny | Female | US English | Professional, clear |
| `en-US-AriaNeural` | Aria | Female | US English | Conversational |
| `en-GB-RyanNeural` | Ryan | Male | British | Formal presentations |

### Discovering All Voices
```python
import asyncio, edge_tts
async def list_voices():
    voices = await edge_tts.list_voices()
    for v in voices:
        if v['Locale'].startswith('en'):
            print(f"  {v['ShortName']} — {v['FriendlyName']} ({v['Gender']})")
asyncio.run(list_voices())
```

## Process

### Step 1: Probe Source Video
```bash
ffprobe -v error -print_format json -show_format -show_streams /tmp/input.mp4
```
Extract: duration, resolution, codec, fps, audio sample rate. Present summary table.

### Step 2: Extract Transcript with Whisper
```python
import whisper
model = whisper.load_model("base")
result = model.transcribe("/tmp/input.mp4", word_timestamps=True, verbose=False)
```
- Use `base` model for speed, `medium` for accuracy on unclear audio
- Save full result to `/tmp/whisper_transcript.json`
- Print the raw transcript for user review

### Step 3: Clean the Transcript
This is CRITICAL for quality. The raw Whisper output contains:
- **Filler words**: "you know", "like", "um", "uh", "OK so", "right?"
- **Repetitions**: "employee employee", stutters
- **Misheard product names**: "DevRef" → "DevRev", "de-agent" → "AI agent"
- **Grammar issues**: "it tries to triage us" → "it tries to triage the problem"
- **Run-on sentences**: Split into natural breath groups

Create a single clean script as continuous prose with paragraph breaks for natural pauses. DO NOT keep segment-by-segment structure — write it as one flowing narration.

### Step 4: Match Duration with Rate Control
Generate the narration and measure against video duration:

```python
import asyncio, edge_tts
from pydub import AudioSegment

# Test multiple rates to find the best match
for rate in ["-15%", "-20%", "-25%", "-30%"]:
    comm = edge_tts.Communicate(script, voice, rate=rate, pitch="+0Hz", volume="+0%")
    await comm.save(f"/tmp/narration_{rate}.mp3")
    dur = len(AudioSegment.from_mp3(f"/tmp/narration_{rate}.mp3")) / 1000
    print(f"rate={rate} -> {dur:.1f}s (target: {video_duration:.1f}s)")
```

Pick the rate that gets closest to the video duration (within +/- 2 seconds).

**IMPORTANT**: Always lock `pitch="+0Hz"` and `volume="+0%"` for consistency.

### Step 5: Generate Final Narration
```python
async def generate():
    comm = edge_tts.Communicate(
        script, 
        "en-US-AndrewNeural",  # or user's chosen voice
        rate=best_rate,         # from Step 4
        pitch="+0Hz",           # locked — no variation
        volume="+0%"            # locked — consistent level
    )
    await comm.save("/tmp/final_narration.mp3")
asyncio.run(generate())
```

### Step 6: Merge Audio into Video
```bash
ffmpeg -i /tmp/input.mp4 \
  -i /tmp/final_narration.mp3 \
  -c:v copy \
  -map 0:v:0 -map 1:a:0 \
  -af "loudnorm=I=-16:TP=-1.5:LRA=5" \
  -c:a aac -b:a 192k \
  -shortest \
  -movflags +faststart \
  -y /path/to/output_dubbed.mp4
```

Key flags:
- `-c:v copy` — no video re-encode (fast, lossless)
- `-map 0:v:0 -map 1:a:0` — take video from input, audio from narration
- `-af "loudnorm=I=-16:TP=-1.5:LRA=5"` — EBU R128 broadcast loudness normalization
- `-shortest` — trim to shorter of video/audio
- `-movflags +faststart` — enable web streaming

### Step 7: Speed Up (Optional)
If user wants faster playback (e.g., 1.3x):
```bash
ffmpeg -i dubbed.mp4 \
  -filter_complex "[0:v]setpts=PTS/1.3[v];[0:a]atempo=1.3[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx265 -crf 28 -preset medium -tag:v hvc1 \
  -c:a aac -b:a 192k \
  -movflags +faststart \
  -y output_1.3x.mp4
```
- `setpts=PTS/N` speeds up video by Nx
- `atempo=N` speeds up audio by Nx without pitch change
- Requires video re-encode (can't use `-c:v copy` with filter)

### Step 8: Verify and Deliver
```bash
ffprobe -v error -show_entries format=duration,size -of default=noprint_wrappers=1 output.mp4
```
- Confirm duration matches expected
- Confirm file plays: `open output.mp4`
- Report before/after comparison table

## Output Naming Convention

| Scenario | Output Name |
|----------|-------------|
| Basic dub | `{input_name}-{voice_name}.mp4` |
| Dub + speed | `{input_name}-{voice_name}-{speed}x.mp4` |
| Example | `UCase2-Laptop Replacement-Andrew.mp4` |
| Example | `UCase2-Laptop Replacement-Andrew-1.3x.mp4` |

## Gotchas

- **NEVER use segment-by-segment TTS generation** — it creates inconsistent pitch, tempo, and volume across segments. Always generate ONE continuous narration for the entire script.
- **macOS Unicode filenames**: Screen recordings have hidden Unicode characters (narrow no-break space before AM/PM). Always glob-match: `cp /path/Screen*Recording*PM.mov /tmp/clean.mp4`
- **Whisper on CPU**: Will warn about FP16 — this is normal, it falls back to FP32 automatically
- **Edge TTS is not offline**: It streams from Microsoft servers. Requires internet connection.
- **Rate limits**: Edge TTS has no documented rate limits but generating very long scripts (>30 min) may timeout — split into chunks if needed
- **Filler words are the #1 quality killer**: Whisper transcribes every "you know", "um", "like" literally. TTS reads them robotically. ALWAYS clean the transcript.
- **Duration matching**: Clean scripts are always shorter than original speech (fillers removed). Use negative rate (-20% to -35%) to slow TTS to match video duration. Test multiple rates.
- **Pitch lock**: Always set `pitch="+0Hz"` — without it, Edge TTS may vary pitch across paragraphs
- **loudnorm filter**: Always apply `loudnorm=I=-16:TP=-1.5:LRA=5` during merge for broadcast-standard consistent volume
- **Speed up requires re-encode**: `setpts` and `atempo` filters need full video re-encode — use H.265 CRF 28 with `-tag:v hvc1` for Apple compatibility
