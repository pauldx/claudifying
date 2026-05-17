---
name: cf-tools-md-to-docx
description: "Convert Markdown to Microsoft Word .docx via pandoc, with optional reference styling. Trigger: /cf-tools-md-to-docx"
trigger: /cf-tools-md-to-docx
version: 1.0.0
---

# /cf-tools-md-to-docx

Convert Markdown to a Word document (`.docx`). Uses `pandoc` (3.x+). Optionally apply a reference document for corporate fonts/colors/styles.

## Usage

```
/cf-tools-md-to-docx input.md                                  # → input.docx, default style
/cf-tools-md-to-docx input.md out.docx
/cf-tools-md-to-docx input.md out.docx --reference template.docx     # custom styles
/cf-tools-md-to-docx input.md out.docx --toc
/cf-tools-md-to-docx input.md out.docx --number-sections
```

Arguments:
1. `md-path` (required)
2. `out-path` (optional, default `<stem>.docx`)
3. `--reference path.docx` — reference document for paragraph/heading/font styles
4. `--toc` — insert a table of contents at the start
5. `--number-sections` — auto-number headings (1, 1.1, 1.2, …)

## What You Must Do When Invoked

### Step 1 — Verify pandoc

```bash
if ! command -v pandoc >/dev/null 2>&1; then
  echo "ERROR: pandoc not installed. Run: brew install pandoc" >&2
  exit 1
fi
```

### Step 2 — Parse args

```bash
MD_PATH="$1"; shift
OUT_PATH=""
REF_DOC=""
TOC_FLAG=""
NUM_FLAG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --reference) REF_DOC="$2"; shift 2 ;;
    --toc) TOC_FLAG="--toc"; shift ;;
    --number-sections) NUM_FLAG="--number-sections"; shift ;;
    -*) shift ;;
    *) [ -z "$OUT_PATH" ] && OUT_PATH="$1"; shift ;;
  esac
done

[ ! -f "$MD_PATH" ] && { echo "ERROR: not found: $MD_PATH" >&2; exit 1; }
[ -z "$OUT_PATH" ] && OUT_PATH="${MD_PATH%.md}.docx"
[ -n "$REF_DOC" ] && [ ! -f "$REF_DOC" ] && { echo "ERROR: reference doc not found: $REF_DOC" >&2; exit 1; }
```

### Step 3 — Build and run

```bash
CMD=(pandoc -f gfm -t docx -o "$OUT_PATH")
[ -n "$REF_DOC" ] && CMD+=(--reference-doc="$REF_DOC")
[ -n "$TOC_FLAG" ] && CMD+=("$TOC_FLAG" --toc-depth=3)
[ -n "$NUM_FLAG" ] && CMD+=("$NUM_FLAG")
CMD+=("$MD_PATH")

echo "Running: ${CMD[*]}" >&2
"${CMD[@]}"
```

### Step 4 — Report

```bash
if [ -f "$OUT_PATH" ]; then
  BYTES=$(wc -c < "$OUT_PATH" | tr -d ' ')
  echo "✅ docx written → $OUT_PATH ($BYTES bytes)" >&2
fi
```

## Generating a reference template

To create a starter reference doc you can edit in Word:

```bash
pandoc -o reference.docx --print-default-data-file reference.docx
# Open reference.docx in Word, modify styles (fonts, colors, spacing), save.
# Then pass it via --reference reference.docx on subsequent runs.
```

Pandoc reads paragraph styles named:
- `Normal`, `Heading 1` … `Heading 6`
- `Code`, `Source Code`, `Block Text`, `Caption`
- `Table Heading`, `Table Caption`, `Compact`

Modify these in Word and the styling carries over to every conversion.

## Output Contract

```
## Markdown → docx

**Source:**     <md-path>
**Output:**     <docx-path>
**Reference:**  <template or default>
**TOC:**        yes | no
**Numbering:**  yes | no
**Size:**       <bytes / KB>
```

## Gotchas

- **Reference doc must be a `.docx`**, not a `.dotx` template. Pandoc reads the style definitions, not the template framework.
- **Images and embedded media** — pandoc embeds relative-path images into the .docx automatically. Web URLs are inlined too (requires network at conversion time).
- **Math**: pandoc supports OMML (Office Math) natively. `$x^2$` becomes an editable equation field, not a rendered image.
- **Code blocks** use the `Source Code` paragraph style. Customize fonts and shading there.
- **Tables**: GFM pipe tables convert to native Word tables. Cell shading and borders inherit from the `Table` style (or `Table Grid` if no reference doc).
- **Page breaks**: insert `\newpage` or pandoc-flavored `\pagebreak` in markdown to force a Word page break.
- **Hyperlinks** preserve target text but you can't restyle the auto-generated `Hyperlink` character style without editing the reference doc.
- **`--toc` placement** — pandoc puts the ToC at the very top, before the first heading. It's a static SDT field, not a live Word ToC; right-click → Update Field in Word to refresh.

## Cross-Platform Notes

- **macOS**: `brew install pandoc`.
- **Linux**: `apt install pandoc`.
- **Windows**: `choco install pandoc` or .msi installer.
- **Pandoc version**: 2.11+ supports `--reference-doc`; older `--reference-docx` flag is deprecated. This skill targets pandoc 3.x.
