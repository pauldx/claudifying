---
name: cf-tools-image-strip-metadata
description: "Remove EXIF, GPS, and other metadata from images using exiftool. Trigger: /cf-tools-image-strip-metadata"
trigger: /cf-tools-image-strip-metadata
version: 1.0.0
---

# /cf-tools-image-strip-metadata

Strip EXIF, GPS, IPTC, XMP, color profile, and other metadata before sharing publicly. Privacy- and bandwidth-friendly.

## Usage

```
/cf-tools-image-strip-metadata <input>                     # strip all, in-place
/cf-tools-image-strip-metadata <input> --output clean.jpg  # write to new file
/cf-tools-image-strip-metadata <input> --keep-orientation  # preserve only orientation tag
/cf-tools-image-strip-metadata <input> --keep-icc          # preserve color profile
/cf-tools-image-strip-metadata <input> --gps-only          # strip GPS only, keep camera/EXIF
```

Flags:
- `--output PATH` — by default writes a `-clean.<ext>` sidecar (exiftool's `-overwrite_original` is the in-place mode)
- `--keep-orientation` — preserve EXIF Orientation tag (prevents auto-rotated photos from displaying sideways)
- `--keep-icc` — preserve ICC color profile (matters for print/wide-gamut workflows)
- `--gps-only` — strip GPS coordinates only; keep camera model, settings, dates
- `--in-place` — overwrite original (no backup)

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
STEM="${INPUT%.*}"
EXT="${INPUT##*.}"
OUTPUT="${STEM}-clean.${EXT}"
KEEP_ORI=0; KEEP_ICC=0; GPS_ONLY=0; INPLACE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --output)           OUTPUT="$2"; shift 2;;
    --keep-orientation) KEEP_ORI=1; shift;;
    --keep-icc)         KEEP_ICC=1; shift;;
    --gps-only)         GPS_ONLY=1; shift;;
    --in-place)         INPLACE=1; shift;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done
```

### Step 2 — Show what's about to be stripped

```bash
echo "--- Before ---"
exiftool -s -G "$INPUT" | grep -iE "(GPS|Camera|Make|Model|Software|DateTime|Orientation|ICC)" | head -20
```

### Step 3 — Strip via exiftool

```bash
if [ "$INPLACE" = "1" ]; then
  TARGET="$INPUT"
  FLAGS="-overwrite_original"
else
  cp "$INPUT" "$OUTPUT"
  TARGET="$OUTPUT"
  FLAGS="-overwrite_original"
fi

if [ "$GPS_ONLY" = "1" ]; then
  exiftool $FLAGS -gps:all= -xmp:geotag= "$TARGET"
elif [ "$KEEP_ORI" = "1" ] && [ "$KEEP_ICC" = "1" ]; then
  exiftool $FLAGS -all= --orientation --icc_profile:all "$TARGET"
elif [ "$KEEP_ORI" = "1" ]; then
  exiftool $FLAGS -all= --orientation "$TARGET"
elif [ "$KEEP_ICC" = "1" ]; then
  exiftool $FLAGS -all= --icc_profile:all "$TARGET"
else
  exiftool $FLAGS -all= "$TARGET"
fi
```

### Step 4 — Verify

```bash
echo "--- After ---"
REMAINING=$(exiftool -s -G "$TARGET" | grep -cvE "^(File|ExifTool|---)")
echo "Remaining non-file tags: $REMAINING"
echo "Output: $TARGET"
```

## Output Contract

```
## Metadata strip

**Input:**       <path>
**Output:**      <path>
**Mode:**        all | gps-only | keep-orientation | keep-icc
**Tags before:** <count>
**Tags after:**  <count>
**Notable removed:** GPS, Camera make/model, Software, DateTime, etc.
```

## Verified Test

`exiftool -overwrite_original -all= sample.jpg` → "1 image files updated", metadata-related tags removed (File* tags remain — those are filesystem-level).

## Gotchas

- **`-all=` only strips the **value**, not the tag structure** — some viewers still see empty tags. For paranoid wipes also add `-tagsfromfile @ -filemodifydate`.
- **JPEG strip via `magick -strip`** removes most metadata but exiftool is more thorough (handles XMP/IPTC consistently).
- **Filesystem timestamps leak data** — `File Modification Date/Time` survives unless you `touch -t` the output afterward.
- **PNG and WebP have less metadata** to strip but may still contain `tEXt`/`zTXt` chunks (PNG) or EXIF (WebP v0.4+).
- **exiftool always backs up** unless `-overwrite_original` is passed; otherwise you get a `_original` sidecar.
- **Color profile loss can shift colors** noticeably on wide-gamut displays. Use `--keep-icc` for print workflows.

## Cross-Platform Notes

- **macOS**: `brew install exiftool`. ImageMagick `-strip` is a less thorough fallback.
- **Linux**: `apt install libimage-exiftool-perl` (yes, perl package — exiftool is a Perl script).
- **Windows**: exiftool standalone .exe from exiftool.org.

If exiftool is missing, `magick "$INPUT" -strip "$OUTPUT"` handles most cases but won't differentiate `--gps-only` vs `--keep-icc` modes.
