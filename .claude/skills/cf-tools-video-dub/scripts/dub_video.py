#!/usr/bin/env python3
"""
Video Dubbing Pipeline — Single continuous narration approach.

Usage:
    python3 dub_video.py <input_video> [--voice en-US-AndrewNeural] [--speed 1.0]

Pipeline:
    1. Probe video for duration
    2. Transcribe with Whisper (word-level timestamps)
    3. Clean transcript (remove fillers, fix grammar)
    4. Find optimal TTS rate to match video duration
    5. Generate single continuous narration via Edge TTS
    6. Merge narration into video with loudness normalization
    7. Optionally speed up the final result
"""

import argparse
import asyncio
import json
import os
import re
import subprocess
import sys
import tempfile

# ── Helpers ─────────────────────────────────────────────────────────────────

def probe_video(path):
    """Get video duration and metadata via ffprobe."""
    cmd = [
        "ffprobe", "-v", "error", "-print_format", "json",
        "-show_format", "-show_streams", path
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(result.stdout)
    duration = float(data["format"]["duration"])
    size_mb = int(data["format"]["size"]) / 1048576
    vs = next(s for s in data["streams"] if s["codec_type"] == "video")
    return {
        "duration": duration,
        "size_mb": size_mb,
        "width": vs["width"],
        "height": vs["height"],
        "codec": vs["codec_name"],
        "fps": vs["r_frame_rate"],
    }


def transcribe(video_path, model_name="base"):
    """Transcribe video audio with Whisper."""
    import whisper
    model = whisper.load_model(model_name)
    result = model.transcribe(video_path, word_timestamps=True, verbose=False)
    return result


def clean_transcript(raw_text):
    """Remove filler words and clean up common transcription artifacts."""
    text = raw_text

    # Remove common fillers
    fillers = [
        r'\b[Yy]ou know,?\s*',
        r'\b[Oo][Kk],?\s+(?:so|like)\s+',
        r'\b[Ll]ike,?\s+',
        r'\b[Uu]m+,?\s+',
        r'\b[Uu]h+,?\s+',
        r'\b[Rr]ight\?\s*',
        r'\b[Ss]o,?\s+(?=so\b)',  # double "so so"
    ]
    for pattern in fillers:
        text = re.sub(pattern, '', text)

    # Fix common Whisper misheard words (extend as needed)
    replacements = {
        'DevRef': 'DevRev',
        'Devreb': 'DevRev',
        'dev ref': 'DevRev',
        'de-agent': 'AI agent',
        'deagent': 'AI agent',
        'air sync': 'Airdrop sync',
        'dev air sync': 'DevRev Airdrop sync',
        'computer surface': 'conversational surface',
        'team surface': 'Teams',
    }
    for old, new in replacements.items():
        text = re.sub(re.escape(old), new, text, flags=re.IGNORECASE)

    # Clean up whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text


async def find_best_rate(script, voice, target_duration):
    """Test multiple TTS rates and find the closest match to target duration."""
    import edge_tts
    from pydub import AudioSegment

    best_rate = "+0%"
    best_diff = float("inf")

    rates = ["+0%", "-5%", "-10%", "-15%", "-20%", "-25%", "-30%", "-35%"]
    for rate in rates:
        path = os.path.join(tempfile.gettempdir(), f"rate_test_{rate}.mp3")
        comm = edge_tts.Communicate(script, voice, rate=rate, pitch="+0Hz", volume="+0%")
        await comm.save(path)
        dur = len(AudioSegment.from_mp3(path)) / 1000
        diff = abs(dur - target_duration)
        print(f"  rate={rate:>5} -> {dur:.1f}s (target: {target_duration:.1f}s, diff: {diff:+.1f}s)")
        if diff < best_diff:
            best_diff = diff
            best_rate = rate
        # Clean up
        os.remove(path)
        # Stop if we found a close enough match
        if diff < 2.0:
            break

    print(f"\n  Best rate: {best_rate} (diff: {best_diff:.1f}s)")
    return best_rate


async def generate_narration(script, voice, rate, output_path):
    """Generate the full narration as a single continuous audio track."""
    import edge_tts
    comm = edge_tts.Communicate(script, voice, rate=rate, pitch="+0Hz", volume="+0%")
    await comm.save(output_path)


def merge_audio_video(video_path, audio_path, output_path):
    """Merge narration audio into video with loudness normalization."""
    cmd = [
        "ffmpeg", "-i", video_path, "-i", audio_path,
        "-c:v", "copy",
        "-map", "0:v:0", "-map", "1:a:0",
        "-af", "loudnorm=I=-16:TP=-1.5:LRA=5",
        "-c:a", "aac", "-b:a", "192k",
        "-shortest",
        "-movflags", "+faststart",
        "-y", output_path
    ]
    subprocess.run(cmd, capture_output=True)


def speed_up(input_path, output_path, speed):
    """Speed up both video and audio by the given factor."""
    cmd = [
        "ffmpeg", "-i", input_path,
        "-filter_complex",
        f"[0:v]setpts=PTS/{speed}[v];[0:a]atempo={speed}[a]",
        "-map", "[v]", "-map", "[a]",
        "-c:v", "libx265", "-crf", "28", "-preset", "medium", "-tag:v", "hvc1",
        "-c:a", "aac", "-b:a", "192k",
        "-movflags", "+faststart",
        "-y", output_path
    ]
    subprocess.run(cmd, capture_output=True)


# ── Main ────────────────────────────────────────────────────────────────────

async def main():
    parser = argparse.ArgumentParser(description="Dub a video with AI narration")
    parser.add_argument("input", help="Input video file path")
    parser.add_argument("--voice", default="en-US-AndrewNeural", help="Edge TTS voice ID")
    parser.add_argument("--speed", type=float, default=1.0, help="Playback speed multiplier (e.g., 1.3)")
    parser.add_argument("--script", help="Path to pre-cleaned script file (skip transcription)")
    parser.add_argument("--whisper-model", default="base", help="Whisper model: tiny, base, small, medium")
    args = parser.parse_args()

    tmpdir = tempfile.gettempdir()

    # Step 1: Probe
    print("\n=== Step 1: Probing video ===")
    info = probe_video(args.input)
    print(f"  Duration: {info['duration']:.1f}s | {info['width']}x{info['height']} | {info['codec']} | {info['size_mb']:.1f}MB")

    # Step 2: Transcribe or load script
    if args.script:
        print(f"\n=== Step 2: Loading script from {args.script} ===")
        with open(args.script) as f:
            script = f.read().strip()
    else:
        print("\n=== Step 2: Transcribing with Whisper ===")
        result = transcribe(args.input, args.whisper_model)
        raw_text = result["text"]
        print(f"  Raw transcript ({len(raw_text)} chars):\n  {raw_text[:200]}...")

        print("\n=== Step 3: Cleaning transcript ===")
        script = clean_transcript(raw_text)
        print(f"  Cleaned ({len(script)} chars):\n  {script[:200]}...")

    # Step 4: Find best rate
    print(f"\n=== Step 4: Finding optimal speech rate for {info['duration']:.1f}s ===")
    best_rate = await find_best_rate(script, args.voice, info["duration"])

    # Step 5: Generate narration
    print(f"\n=== Step 5: Generating narration ({args.voice}, rate={best_rate}) ===")
    narration_path = os.path.join(tmpdir, "dub_narration.mp3")
    await generate_narration(script, args.voice, best_rate, narration_path)
    from pydub import AudioSegment
    nar_dur = len(AudioSegment.from_mp3(narration_path)) / 1000
    print(f"  Generated: {nar_dur:.1f}s")

    # Step 6: Merge
    base_name = os.path.splitext(os.path.basename(args.input))[0]
    voice_short = args.voice.split("-")[-1].replace("Neural", "")

    if args.speed != 1.0:
        # Merge first, then speed up
        merged_path = os.path.join(tmpdir, "dub_merged.mp4")
        output_name = f"{base_name}-{voice_short}-{args.speed}x.mp4"
    else:
        merged_path = None
        output_name = f"{base_name}-{voice_short}.mp4"

    output_path = os.path.join(os.path.dirname(args.input), output_name)
    target_merge = merged_path or output_path

    print(f"\n=== Step 6: Merging audio into video ===")
    merge_audio_video(args.input, narration_path, target_merge)
    print(f"  Merged: {target_merge}")

    # Step 7: Speed up if requested
    if args.speed != 1.0:
        print(f"\n=== Step 7: Speeding up to {args.speed}x ===")
        speed_up(target_merge, output_path, args.speed)
        os.remove(merged_path)

    # Step 8: Verify
    print(f"\n=== Step 8: Verification ===")
    out_info = probe_video(output_path)
    print(f"  Output: {output_path}")
    print(f"  Duration: {out_info['duration']:.1f}s | Size: {out_info['size_mb']:.1f}MB")
    print(f"\n  Done!")


if __name__ == "__main__":
    asyncio.run(main())
