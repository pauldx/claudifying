# Lessons Learned from Video Dubbing Pipeline Development

## What Failed

### 1. Segment-by-Segment TTS (V1-V5)
**Approach**: Transcribe with Whisper -> split into 58 segments -> generate TTS per segment -> assemble timeline
**Problem**: Each segment had different pitch, tempo, volume. Rate hacks (+15%, -25%) per segment made it worse. Sounded like a patchwork quilt of different speakers.

### 2. librosa time_stretch (V2)
**Approach**: Use librosa to time-stretch generated audio to fit original segment timing
**Problem**: Created ghosting/distortion artifacts. The phase vocoder introduced audible warping that sounded robotic and unclear.

### 3. Per-segment loudness normalization (V2-V3)
**Approach**: Normalize each segment to -16 dBFS independently
**Problem**: Still had volume inconsistency because each segment's content differed (short "Right." vs long sentences). RMS normalization on short segments is unreliable.

### 4. Kokoro TTS
**Approach**: Use Kokoro (free, open-source TTS with voice cloning)
**Problem**: Required ONNX model downloads from HuggingFace, dependency conflicts with onnxruntime versions, Python 3.9 incompatibility (uses `str | None` syntax). Too many friction points.

### 5. Hard trimming segments
**Approach**: If TTS segment was longer than time slot, hard-cut at the boundary
**Problem**: Words got chopped mid-syllable, creating abrupt cutoffs.

## What Worked

### Single Continuous Narration (V6 - FINAL)
**Approach**: Generate the ENTIRE script as ONE continuous TTS call
**Why it works**: 
- One voice, one pitch, one tempo throughout
- Edge TTS naturally handles pacing, pauses, breath groups
- No segment boundaries = no stitching artifacts
- Rate control (`-30%`) applied uniformly = consistent speed

### Edge TTS with Andrew voice
- `en-US-AndrewNeural` — professional male American voice
- Free, no API key, no rate limits
- Excellent quality for demo/presentation narration
- SSML rate/pitch/volume control for fine-tuning

### Duration matching via rate testing
- Clean script is always shorter than original (fillers removed)
- Test rates from 0% to -35% to find closest match to video duration
- `-30%` hit within 0.4s of target — essentially perfect

### ffmpeg loudnorm filter
- `loudnorm=I=-16:TP=-1.5:LRA=5` applied during final merge
- EBU R128 broadcast standard — consistent professional volume
- Single pass, handles the entire audio uniformly

### Speed up with setpts + atempo
- `setpts=PTS/1.3` for video, `atempo=1.3` for audio
- Maintains pitch (no chipmunk effect)
- Requires video re-encode but result is clean

## Key Principle
**Never generate TTS segment-by-segment. Always generate one continuous narration and match its duration to the video using rate control.**
