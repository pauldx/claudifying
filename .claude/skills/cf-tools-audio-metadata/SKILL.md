---
name: cf-tools-audio-metadata
description: "Read or write audio metadata (ID3 tags, codec info, duration) via ffprobe + ffmpeg. Trigger: /cf-tools-audio-metadata"
trigger: /cf-tools-audio-metadata
version: 1.0.0
---

# /cf-tools-audio-metadata

Inspect codec / container / tag info, or write ID3v2 tags (title, artist, album, year, track, genre, album art).

## Usage

### Read

```
/cf-tools-audio-metadata input.mp3                           # full report
/cf-tools-audio-metadata input.mp3 --json                    # machine-readable
/cf-tools-audio-metadata input.mp3 --tags-only               # just ID3
/cf-tools-audio-metadata input.mp3 --field duration          # one value
```

### Write

```
/cf-tools-audio-metadata input.mp3 --write \
  --title "Episode 42" --artist "Show Name" --album "Season 3" \
  --year 2026 --track 12 --genre "Podcast" \
  --output tagged.mp3

/cf-tools-audio-metadata input.mp3 --write --cover cover.jpg --output tagged.mp3
```

## What You Must Do When Invoked

### Step 1 — Detect mode

```bash
INPUT="$1"; shift
MODE="read"
for arg in "$@"; do
  [ "$arg" = "--write" ] && MODE="write" && break
done
[ -f "$INPUT" ] || { echo "ERROR: input not found"; exit 1; }
```

### Step 2a — Read mode: full report

```bash
if [ "$MODE" = "read" ]; then
  FORMAT="text"; FIELD=""; TAGS_ONLY=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) FORMAT="json"; shift ;;
      --tags-only) TAGS_ONLY=1; shift ;;
      --field) FIELD="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -n "$FIELD" ]; then
    ffprobe -v error -show_entries "format=${FIELD}" -show_entries "stream=${FIELD}" \
      -of default=noprint_wrappers=1:nokey=1 "$INPUT"
    exit 0
  fi

  if [ "$FORMAT" = "json" ]; then
    ffprobe -v error -show_format -show_streams -of json "$INPUT"
    exit 0
  fi

  if [ "$TAGS_ONLY" -eq 1 ]; then
    ffprobe -v error -show_entries format_tags -of default=noprint_wrappers=1 "$INPUT"
    exit 0
  fi

  # Default: structured human report
  ffprobe -v error \
    -show_entries format=filename,format_name,duration,size,bit_rate \
    -show_entries stream=codec_name,codec_long_name,sample_rate,channels,channel_layout \
    -show_entries format_tags=title,artist,album,date,track,genre,composer,album_artist \
    -of default=noprint_wrappers=1 "$INPUT"
  exit 0
fi
```

### Step 2b — Write mode

```bash
if [ "$MODE" = "write" ]; then
  OUTPUT=""; COVER=""
  declare -a META_ARGS
  while [ $# -gt 0 ]; do
    case "$1" in
      --write) shift ;;
      --output) OUTPUT="$2"; shift 2 ;;
      --cover) COVER="$2"; shift 2 ;;
      --title) META_ARGS+=(-metadata "title=$2"); shift 2 ;;
      --artist) META_ARGS+=(-metadata "artist=$2"); shift 2 ;;
      --album) META_ARGS+=(-metadata "album=$2"); shift 2 ;;
      --album-artist) META_ARGS+=(-metadata "album_artist=$2"); shift 2 ;;
      --year) META_ARGS+=(-metadata "date=$2"); shift 2 ;;
      --track) META_ARGS+=(-metadata "track=$2"); shift 2 ;;
      --genre) META_ARGS+=(-metadata "genre=$2"); shift 2 ;;
      --composer) META_ARGS+=(-metadata "composer=$2"); shift 2 ;;
      --comment) META_ARGS+=(-metadata "comment=$2"); shift 2 ;;
      *) shift ;;
    esac
  done
  [ -n "$OUTPUT" ] || { echo "ERROR: --output required for write mode"; exit 1; }

  if [ -n "$COVER" ]; then
    [ -f "$COVER" ] || { echo "ERROR: cover not found: $COVER"; exit 1; }
    ffmpeg -y -i "$INPUT" -i "$COVER" \
      -map 0:a -map 1:v \
      -c:a copy -c:v copy \
      -disposition:v:0 attached_pic \
      -id3v2_version 3 \
      "${META_ARGS[@]}" "$OUTPUT"
  else
    ffmpeg -y -i "$INPUT" -c copy -id3v2_version 3 \
      "${META_ARGS[@]}" "$OUTPUT"
  fi
fi
```

### Step 3 — Verify write result

```bash
ffprobe -v error -show_entries format_tags -of default=noprint_wrappers=1 "$OUTPUT"
```

## Output Contract (read)

```
## Audio metadata

**File:**         <filename>
**Container:**    <format_name>
**Duration:**     <s>s
**Bitrate:**      <kbps>
**Size:**         <bytes / MB>

**Stream 0 (audio):**
  Codec:        <codec_name> (<codec_long_name>)
  Sample rate:  <Hz>
  Channels:     <N> (<layout>)

**Tags:**
  title:        <...>
  artist:       <...>
  album:        <...>
  date:         <...>
  track:        <...>
  genre:        <...>
```

## Output Contract (write)

```
## Audio metadata write

**Source:**       <input>
**Output:**       <output>
**Tags applied:** <count> fields
**Cover art:**    embedded | none
**Result tags:**  (verification dump)
```

## Common Tag Keys

| Field         | ID3 frame | ffmpeg `-metadata` key |
|---------------|-----------|------------------------|
| Title         | TIT2      | `title`                |
| Artist        | TPE1      | `artist`               |
| Album artist  | TPE2      | `album_artist`         |
| Album         | TALB      | `album`                |
| Year/Date     | TDRC      | `date`                 |
| Track number  | TRCK      | `track`                |
| Genre         | TCON      | `genre`                |
| Composer      | TCOM      | `composer`             |
| Comment       | COMM      | `comment`              |
| BPM           | TBPM      | `TBPM`                 |
| Lyrics        | USLT      | `lyrics`               |

## Gotchas

- **ID3v1 vs ID3v2**: `-id3v2_version 3` forces ID3v2.3 (most compatible). ID3v1 is 30-char limited and obsolete; skip it.
- **WAV / FLAC tag formats differ**: FLAC uses Vorbis comments; WAV uses RIFF INFO. ffmpeg maps `-metadata` keys automatically — don't hand-write field names.
- **Cover art only for mp3/m4a/flac**: container must support attached pictures. Ogg/Opus need different invocation.
- **`date` vs `year`**: ID3v2.4 uses TDRC (full date); v2.3 uses TYER (year only). `date=2026-05-16` is safest — readers parse the year.
- **Overwrite a file in place**: write to a temp output, then `mv`. ffmpeg refuses to read and write the same file.
- **Tag stripping**: `ffmpeg -i in.mp3 -map_metadata -1 -c copy clean.mp3` removes all tags.

## Cross-Platform Notes

- ffprobe / ffmpeg cover everything; no extra tools needed.
- Optional: `mid3v2` (Python `mutagen`) for fine-grained ID3 editing; `kid3-cli` for batch tag operations.
