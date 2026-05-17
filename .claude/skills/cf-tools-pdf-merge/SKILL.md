---
name: cf-tools-pdf-merge
description: "Merge multiple PDFs into one using poppler pdfunite. Trigger: /cf-tools-pdf-merge"
trigger: /cf-tools-pdf-merge
version: 1.0.0
---

# /cf-tools-pdf-merge

Concatenate two or more PDFs into a single output file. Primary tool: `pdfunite` (poppler) — lossless, preserves bookmarks and metadata of the first PDF. Falls back to `qpdf` or `ghostscript` if pdfunite is unavailable.

## Usage

```
/cf-tools-pdf-merge a.pdf b.pdf out.pdf
/cf-tools-pdf-merge cover.pdf body.pdf appendix.pdf final.pdf
```

Arguments:
1..N-1. Input PDFs in the order they should appear
N. Output PDF path (last argument is always the destination)

Minimum 3 arguments (2 inputs + 1 output).

## Why pdfunite

| Tool | Lossless | Speed | Install |
|---|---|---|---|
| `pdfunite` (poppler) | ✅ | ✅ | `brew install poppler` |
| `qpdf` | ✅ | ✅ | `brew install qpdf` |
| `gs -sDEVICE=pdfwrite` | ⚠️ recompresses | ⚠️ slow | `brew install ghostscript` |
| `pdftk` | ✅ | ✅ | `brew install pdftk-java` |

Use `pdfunite` first. Use `qpdf` for very large files or when pdfunite chokes on encrypted/tagged PDFs. Avoid ghostscript unless you specifically want recompression.

## What You Must Do When Invoked

### Step 1 — Validate inputs

```bash
ARGS=("$@")
NUM=${#ARGS[@]}

if [ "$NUM" -lt 3 ]; then
  echo "ERROR: need at least 2 input PDFs and 1 output path" >&2
  echo "Usage: /cf-tools-pdf-merge in1.pdf in2.pdf [in3.pdf...] out.pdf" >&2
  exit 1
fi

OUTPUT="${ARGS[$((NUM-1))]}"
INPUTS=("${ARGS[@]:0:$((NUM-1))}")

for f in "${INPUTS[@]}"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: input not found: $f" >&2
    exit 1
  fi
done
```

### Step 2 — Try pdfunite (primary)

```bash
if command -v pdfunite >/dev/null 2>&1; then
  echo "Merging via pdfunite..." >&2
  pdfunite "${INPUTS[@]}" "$OUTPUT"
  if [ -f "$OUTPUT" ]; then
    METHOD="pdfunite"
  fi
fi
```

### Step 3 — Fallback to qpdf

```bash
if [ ! -f "$OUTPUT" ] && command -v qpdf >/dev/null 2>&1; then
  echo "pdfunite failed or missing. Trying qpdf..." >&2
  qpdf --empty --pages "${INPUTS[@]}" -- "$OUTPUT"
  METHOD="qpdf"
fi
```

### Step 4 — Fallback to ghostscript

```bash
if [ ! -f "$OUTPUT" ] && command -v gs >/dev/null 2>&1; then
  echo "qpdf failed or missing. Trying ghostscript..." >&2
  gs -dNOPAUSE -dBATCH -dQUIET -sDEVICE=pdfwrite \
    -sOutputFile="$OUTPUT" "${INPUTS[@]}"
  METHOD="ghostscript (recompressed)"
fi

if [ ! -f "$OUTPUT" ]; then
  echo "ERROR: no PDF merger available. Run: brew install poppler" >&2
  exit 1
fi
```

### Step 5 — Verify output page count

```bash
EXPECTED=0
for f in "${INPUTS[@]}"; do
  COUNT=$(pdfinfo "$f" 2>/dev/null | awk '/^Pages:/ {print $2}')
  EXPECTED=$((EXPECTED + COUNT))
done
ACTUAL=$(pdfinfo "$OUTPUT" 2>/dev/null | awk '/^Pages:/ {print $2}')

echo "✅ Merged $NUM-1 PDFs → $OUTPUT" >&2
echo "   Pages: $ACTUAL (expected $EXPECTED) via $METHOD" >&2

if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "⚠️  Page count mismatch — inspect output" >&2
fi
```

## Output Contract

```
## PDF merge

**Inputs:**  <in1.pdf>, <in2.pdf>, ...
**Output:**  <out.pdf>
**Method:**  pdfunite | qpdf | ghostscript
**Pages:**   <actual> (expected <sum>)
**Size:**    <bytes / KB>
```

## Gotchas

- **`pdfunite` requires the output path as the last argument**, not a flag. Order matters.
- **Bookmarks/outline get dropped** by pdfunite except those in the first input. Use `qpdf --collate` or pikepdf if you need merged outlines.
- **Form fields with duplicate names collide** — second occurrence is renamed. Flatten forms first: `qpdf --flatten-annotations=all in.pdf flat.pdf`.
- **Encrypted PDFs fail silently** in pdfunite. Decrypt first: `qpdf --decrypt --password=PWD in.pdf out.pdf`.
- **Mixed page sizes** are preserved as-is — output will have varying page dimensions. Normalize with `gs -sPAPERSIZE=...` if needed.
- **Tagged PDFs lose accessibility tags** in pdfunite. Use `qpdf` or `pikepdf` for tag preservation.

## Cross-Platform Notes

- **macOS**: `brew install poppler` (pdfunite), `brew install qpdf`, `brew install ghostscript`.
- **Linux**: `apt install poppler-utils qpdf ghostscript`.
- **Windows**: install poppler binaries + qpdf release zip, or use WSL.
