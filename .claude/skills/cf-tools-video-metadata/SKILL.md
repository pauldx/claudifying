---
name: cf-tools-video-metadata
description: "Probe a video and display codec, duration, bitrate, fps, resolution, audio streams in a pretty table. Trigger: /cf-tools-video-metadata"
trigger: /cf-tools-video-metadata
version: 1.0.0
---

# /cf-tools-video-metadata

Run `ffprobe` against a video and produce a human-readable summary table plus an optional JSON dump for piping. The pretty output is grouped into Container, Video, Audio, Subtitles sections.

Related skills:
- `/cf-tools-video-thumbnail` — preview using probed timestamps
- `/cf-tools-video-resize` — make decisions based on resolution / bitrate
- `/cf-tools-video-compress` — see current bitrate before re-encoding

## Usage

```
/cf-tools-video-metadata input.mp4
/cf-tools-video-metadata input.mov --json
/cf-tools-video-metadata input.mkv --json > metadata.json
```

Arguments:
1. `input` (required) — video file
2. `--json` (optional) — emit raw ffprobe JSON to stdout instead of pretty table

## What You Must Do When Invoked

### Step 1 — Run ffprobe

```bash
JSON=$(ffprobe -v error -print_format json -show_format -show_streams "$INPUT")
```

If `--json` flag set, print `$JSON` and exit.

### Step 2 — Pretty-format

Use Python (always available) to extract fields:

```bash
python3 - <<PY
import json, sys
d = json.loads('''$JSON''')
fmt = d.get('format', {})
streams = d.get('streams', [])
v = next((s for s in streams if s['codec_type'] == 'video'), None)
a = [s for s in streams if s['codec_type'] == 'audio']
sub = [s for s in streams if s['codec_type'] == 'subtitle']

def hms(sec):
    sec = float(sec); h = int(sec//3600); m = int((sec%3600)//60); s = sec - h*3600 - m*60
    return f"{h:02d}:{m:02d}:{s:06.3f}"

def kbps(b):
    try: return f"{int(b)//1000} kbps"
    except: return "?"

print("=" * 60)
print(f"  {fmt.get('filename', '?')}")
print("=" * 60)
print(f"  Container   : {fmt.get('format_long_name','?')}")
print(f"  Duration    : {hms(fmt.get('duration', 0))}")
print(f"  Size        : {int(fmt.get('size', 0))/1024/1024:.2f} MB")
print(f"  Bitrate     : {kbps(fmt.get('bit_rate'))}")
print()
if v:
    fps_num, fps_den = (v.get('r_frame_rate','0/1').split('/') + ['1'])[:2]
    fps = float(fps_num)/float(fps_den or 1)
    print(f"  Video       : {v.get('codec_name','?')} ({v.get('profile','')})")
    print(f"    Resolution: {v.get('width')}x{v.get('height')}")
    print(f"    FPS       : {fps:.3f}")
    print(f"    Pixel fmt : {v.get('pix_fmt','?')}")
    print(f"    Bitrate   : {kbps(v.get('bit_rate'))}")
else:
    print("  Video       : (none)")
print()
if a:
    for i, s in enumerate(a):
        print(f"  Audio #{i}    : {s.get('codec_name','?')} {s.get('channels','?')}ch "
              f"@ {s.get('sample_rate','?')} Hz, {kbps(s.get('bit_rate'))}")
else:
    print("  Audio       : (none)")
if sub:
    for i, s in enumerate(sub):
        print(f"  Subtitle #{i}: {s.get('codec_name','?')} ({s.get('tags',{}).get('language','??')})")
print("=" * 60)
PY
```

### Step 3 — Done

No output file is produced unless `--json` is redirected.

## Output Contract

```
## Video metadata

============================================================
  /path/to/sample.mp4
============================================================
  Container   : QuickTime / MOV
  Duration    : 00:00:05.000
  Size        : 0.17 MB
  Bitrate     : 278 kbps

  Video       : h264 (Constrained Baseline)
    Resolution: 320x240
    FPS       : 25.000
    Pixel fmt : yuv420p
    Bitrate   : 270 kbps

  Audio       : (none)
============================================================
```

## Gotchas

- `r_frame_rate` is a rational like `30000/1001` for 29.97 fps. Always divide rather than parsing as integer.
- Variable-frame-rate sources report `r_frame_rate` as the max guess. For true average FPS, use `avg_frame_rate`.
- Per-stream `bit_rate` is sometimes missing (especially for MKV). The container `bit_rate` is then the only reliable number.
- ffprobe can hang on broken files; consider adding `-timeout 5000000` (microseconds) for untrusted input.
- JSON mode is the most reliable for scripting — the pretty table is human-only.

## Cross-Platform Notes

Pure ffprobe + Python 3, works on macOS, Linux, Windows. No fonts or codecs needed (probe-only). For batch use, the `--json` mode is friendliest for `jq`-style pipelines.
