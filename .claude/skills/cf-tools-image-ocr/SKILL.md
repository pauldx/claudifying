---
name: cf-tools-image-ocr
description: "Extract text from images using Tesseract OCR with language packs and TSV output. Trigger: /cf-tools-image-ocr"
trigger: /cf-tools-image-ocr
version: 1.0.0
---

# /cf-tools-image-ocr

Convert images of text into searchable text using **Tesseract** (open-source OCR engine, originally from HP, now maintained by Google).

## Usage

```
/cf-tools-image-ocr <input>
/cf-tools-image-ocr <input> --lang eng+deu          # multi-language
/cf-tools-image-ocr <input> --output extracted.txt
/cf-tools-image-ocr <input> --format tsv            # word-level with bbox/conf
/cf-tools-image-ocr <input> --psm 6                 # page segmentation mode
```

Flags:
- `--lang CODES` — ISO 639-3 language codes joined by `+` (default `eng`). Common: `eng`, `deu`, `fra`, `spa`, `chi_sim`, `jpn`, `kor`, `ara`, `hin`, `rus`.
- `--output PATH` — output file (default prints to stdout)
- `--format txt|tsv|hocr|pdf` — `txt` (default), `tsv` (word-level with confidence + bbox), `hocr` (HTML+OCR), `pdf` (searchable PDF)
- `--psm N` — page segmentation mode (default 3 = auto). See gotchas.

## What You Must Do When Invoked

### Step 1 — Check tesseract presence

```bash
INPUT="$1"; shift
[ -f "$INPUT" ] || { echo "ERROR: not found"; exit 1; }
STEM="${INPUT%.*}"
LANG="eng"; FORMAT="txt"; PSM=3; OUTPUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --lang)   LANG="$2"; shift 2;;
    --output) OUTPUT="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    --psm)    PSM="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done

if ! command -v tesseract >/dev/null 2>&1; then
  echo "ERROR: tesseract not installed. brew install tesseract  /  apt install tesseract-ocr"
  exit 2
fi
```

### Step 2 — Preprocess (improves OCR accuracy)

```bash
# Convert to grayscale, normalize contrast, deskew — improves accuracy on low-quality scans
PREPROC="/tmp/_ocr_$$.png"
magick "$INPUT" -colorspace gray -auto-level -deskew 40% "$PREPROC"
```

### Step 3 — Run tesseract

```bash
# tesseract syntax: tesseract <input> <output-stem> [options]
# output-stem omits extension; tesseract appends .txt/.tsv/.hocr/.pdf
if [ -z "$OUTPUT" ]; then
  OUTPUT_STEM="${STEM}-ocr"
else
  OUTPUT_STEM="${OUTPUT%.*}"
fi

CONFIG=""
case "$FORMAT" in
  txt)   CONFIG="";;
  tsv)   CONFIG="tsv";;
  hocr)  CONFIG="hocr";;
  pdf)   CONFIG="pdf";;
  *) echo "ERROR: unsupported --format $FORMAT"; exit 1;;
esac

tesseract "$PREPROC" "$OUTPUT_STEM" -l "$LANG" --psm "$PSM" $CONFIG 2>&1 | grep -v "^Estimating"

rm -f "$PREPROC"
```

### Step 4 — Show result

```bash
EXT_OUT=$([ "$FORMAT" = "txt" ] && echo "txt" || echo "$FORMAT")
RESULT="${OUTPUT_STEM}.${EXT_OUT}"
echo ""
echo "## OCR result"
echo ""
echo "**Input:**   $INPUT"
echo "**Lang:**    $LANG"
echo "**Format:**  $FORMAT"
echo "**Output:**  $RESULT"
echo ""
if [ "$FORMAT" = "txt" ]; then
  echo "--- text ---"
  cat "$RESULT"
fi
```

## Output Contract

```
## OCR result

**Input:**    <path>  (<W>x<H>)
**Lang:**     <codes>
**Format:**   txt | tsv | hocr | pdf
**Output:**   <path>
**Preview:**  (first 200 chars of recognized text)
```

## Verified Test

```bash
magick sample-with-text.png ocr_input.png
tesseract ocr_input.png ocr_out
cat ocr_out.txt
# → "Hello World 12345"
```

Tested live: tesseract correctly extracted text from the `sample-with-text.png` fixture (600x200 grayscale image containing "Hello World 12345").

## Gotchas

- **PSM (Page Segmentation Mode)** drastically changes results:
  - `3` (auto, default) — works for most documents
  - `6` — single uniform block of text (use for screenshots)
  - `7` — single text line (license plates, captions)
  - `8` — single word
  - `10` — single character
  - `11` — sparse text, no order
- **Language packs are separate downloads** — `brew install tesseract-lang` (all langs) or `apt install tesseract-ocr-deu` (per language).
- **`--psm 3` may detect orientation incorrectly** on rotated text — pair with `--osd` or pre-rotate.
- **Low-DPI images** (<150 DPI equivalent) produce garbage. Upscale to ≥300 DPI first via cf-tools-image-upscale.
- **Confidence values** in TSV format (column 11) — anything below 60 is likely wrong. Filter out low-confidence words.
- **Handwriting** — tesseract is poor at handwriting. Use `--psm 7` and lowered expectations, or route to a cloud API.
- **JPEG compression artifacts** confuse the OCR engine — feed PNG/TIFF when possible.

## Cross-Platform Notes

- **macOS**: `brew install tesseract tesseract-lang`. Apple Vision (`shortcuts run "Extract Text from Image"`) is a strong native alternative.
- **Linux**: `apt install tesseract-ocr tesseract-ocr-eng tesseract-ocr-<lang>`.
- **Windows**: tesseract installer from UB-Mannheim builds.

## Alternatives

- Apple Vision (macOS-only, no install, high accuracy)
- Google Cloud Vision / AWS Textract / Azure Form Recognizer (paid, cloud)
- `easyocr` (Python, better on rotated/handwriting)
- `paddleocr` (Chinese-trained, strong on CJK)
