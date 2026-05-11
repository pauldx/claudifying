---
name: cf-create-pdf
description: When the user asks to extract PDF pages, split a PDF, create a new PDF from pages, merge PDFs, copy specific pages, or manipulate PDF files — activate this PDF creation skill
---

# PDF Creator & Manipulator

Extract, split, merge, and manipulate PDF files using available system tools (Ghostscript, Python pypdf/PyPDF2, or qpdf).

## Activation

- "Extract pages 1-3 from this PDF"
- "Split this PDF into separate files"
- "Merge these PDFs together"
- "Copy first 5 pages to a new file"
- "Create a PDF from these pages"
- "Remove pages 4-6 from this PDF"

## Process

### 1. Detect Available Tools

Probe system for PDF-capable tools in priority order:

```bash
# Check all available PDF tools
python3 -c "from pypdf import PdfReader; print('pypdf')" 2>/dev/null
python3 -c "import PyPDF2; print('PyPDF2')" 2>/dev/null
which qpdf 2>/dev/null
which pdftk 2>/dev/null
which gs 2>/dev/null  # Ghostscript — most common fallback on macOS
```

Use first available. If none found, suggest `brew install ghostscript` or `pip install pypdf`.

### 2. Inspect Source PDF

```bash
# Page count via Ghostscript
gs -q -dNODISPLAY -c "($INPUT_FILE) (r) file runpdfbegin pdfpagecount = quit"

# Or via Python
python3 -c "from pypdf import PdfReader; print(len(PdfReader('$INPUT_FILE').pages))"
```

Report page count and file size. If user requested specific pages, validate range.

### 3. Execute Operation

#### Extract / Split Pages

**Ghostscript** (most portable):
```bash
gs -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dQUIET \
  -dFirstPage=$FIRST -dLastPage=$LAST \
  -sOutputFile="$OUTPUT_FILE" "$INPUT_FILE"
```

**pypdf** (Python — cleanest output):
```python
from pypdf import PdfReader, PdfWriter

reader = PdfReader("input.pdf")
writer = PdfWriter()
for page_num in range(first - 1, last):
    writer.add_page(reader.pages[page_num])
writer.write("output.pdf")
```

**qpdf** (fastest for large files):
```bash
qpdf "$INPUT_FILE" --pages . $FIRST-$LAST -- "$OUTPUT_FILE"
```

#### Merge Multiple PDFs

**Ghostscript**:
```bash
gs -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dQUIET \
  -sOutputFile="$OUTPUT_FILE" "$FILE1" "$FILE2" "$FILE3"
```

**pypdf**:
```python
from pypdf import PdfMerger

merger = PdfMerger()
for pdf in ["file1.pdf", "file2.pdf", "file3.pdf"]:
    merger.append(pdf)
merger.write("merged.pdf")
merger.close()
```

**qpdf**:
```bash
qpdf --empty --pages "$FILE1" "$FILE2" "$FILE3" -- "$OUTPUT_FILE"
```

#### Remove Specific Pages

Use pypdf to add all pages except excluded ones:
```python
from pypdf import PdfReader, PdfWriter

reader = PdfReader("input.pdf")
writer = PdfWriter()
exclude = {3, 4, 5}  # 1-indexed pages to remove
for i, page in enumerate(reader.pages):
    if (i + 1) not in exclude:
        writer.add_page(page)
writer.write("output.pdf")
```

With Ghostscript, extract two ranges and merge (e.g., pages 1-2 + 6-end).

### 4. Handle Sandbox Restrictions

Claude Code sandbox may block writes to user directories (Downloads, Desktop). Pattern:

```bash
# Write to sandbox-writable temp dir first
gs ... -sOutputFile="$TMPDIR/output.pdf" "$INPUT_FILE"

# Then copy to target (may need dangerouslyDisableSandbox)
cp "$TMPDIR/output.pdf" "$TARGET_DIR/output.pdf"
```

Always use `$TMPDIR` (not `/tmp` directly) — it resolves to sandbox-writable path.

### 5. Verify Output

```bash
ls -lh "$OUTPUT_FILE"
# Confirm page count
gs -q -dNODISPLAY -c "($OUTPUT_FILE) (r) file runpdfbegin pdfpagecount = quit"
```

Report file size and page count to user.

## Output

- New PDF file at user-specified location
- Page count and file size confirmation
- Tool used for operation

## Gotchas

- **Ghostscript rewrites PDFs** — output file size may differ from original (recompression). Use qpdf or pypdf for byte-accurate extraction.
- **Sandbox blocks writes** to ~/Downloads, ~/Desktop, ~/Documents. Write to `$TMPDIR` first, then copy with `dangerouslyDisableSandbox: true`.
- **`$TMPDIR` differs between sandbox and non-sandbox** — in sandbox it resolves to `/tmp/claude-<uid>/`, outside sandbox it's `/var/folders/...`. Always use the variable, never hardcode.
- **Ghostscript page numbers are 1-indexed** — `-dFirstPage=1 -dLastPage=3` gets pages 1, 2, 3.
- **pypdf page indices are 0-indexed** — `reader.pages[0]` is page 1.
- **Spaces in filenames** break Ghostscript args. Always quote paths: `"$INPUT_FILE"`.
- **Large PDFs (100+ pages)** — Ghostscript loads entire file into memory. For surgical extraction from huge files, prefer qpdf (streaming).
- **Encrypted PDFs** — Ghostscript and pypdf may fail silently. Check for encryption first: `python3 -c "from pypdf import PdfReader; print(PdfReader('file.pdf').is_encrypted)"`.
- **macOS ships without PDF CLI tools** — Ghostscript (`brew install ghostscript`) is most common. pypdf (`pip install pypdf`) is lightest install.
- **Ghostscript `-sOutputFile` uses `-s` prefix** — no space between flag and value, or use `=`.
