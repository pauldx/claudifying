---
name: cf-tools-md-syntax-highlight
description: "Render a Markdown file to standalone HTML with full syntax-highlighted code blocks via pandoc + pygments. Trigger: /cf-tools-md-syntax-highlight"
trigger: /cf-tools-md-syntax-highlight
version: 1.0.0
---

# /cf-tools-md-syntax-highlight

Convert a Markdown file to standalone HTML where every fenced code block is syntax-colored. Uses pandoc's built-in highlighter (no JS at view-time). Output ships with inline CSS classes, no external assets required.

Different from `/cf-tools-md-render-preview` which is optimized for "show me now"; this skill is optimized for **archival HTML with embedded syntax colors**.

## Usage

```
/cf-tools-md-syntax-highlight <markdown-file>
/cf-tools-md-syntax-highlight <markdown-file> /path/out.html
/cf-tools-md-syntax-highlight <markdown-file> /path/out.html --style monokai
/cf-tools-md-syntax-highlight <markdown-file> /path/out.html --no-toc
```

Arguments:
1. `markdown-file` (required)
2. `output` (optional, default `<md-stem>.highlighted.html`)
3. `--style <pygments|tango|espresso|zenburn|kate|monochrome|breezedark|haddock>` (optional, default `pygments`)
4. `--no-toc` (optional) — disable auto-generated table of contents

Pandoc ships these highlight styles natively — no extra install needed.

## What You Must Do When Invoked

### Step 1 — Validate + parse

```bash
MD="$1"
[ ! -f "$MD" ] && { echo "ERROR: $MD not found"; exit 1; }
OUTPUT="${2:-${MD%.md}.highlighted.html}"

STYLE="pygments"; TOC_FLAG="--toc --toc-depth=3"
prev=""; for a in "$@"; do
  [ "$prev" = "--style" ] && STYLE="$a"
  [ "$a" = "--no-toc" ] && TOC_FLAG=""
  prev="$a"
done
```

### Step 2 — Confirm pandoc + style exist

```bash
command -v pandoc >/dev/null || { echo "ERROR: pandoc not installed (brew install pandoc)"; exit 1; }

# Validate style — pandoc errors otherwise. Limit to known set.
VALID_STYLES="pygments tango espresso zenburn kate monochrome breezedark haddock"
echo "$VALID_STYLES" | grep -qw "$STYLE" || {
  echo "ERROR: invalid --style '$STYLE'. Valid: $VALID_STYLES"; exit 1;
}
```

### Step 3 — Render

```bash
# pandoc 3.x prefers --syntax-highlighting; older pandoc only knows --highlight-style.
# Probe once and pick the right flag.
if pandoc --help 2>&1 | grep -q -- "--syntax-highlighting"; then
  HL_FLAG="--syntax-highlighting=$STYLE"
else
  HL_FLAG="--highlight-style=$STYLE"
fi

pandoc "$MD" \
  --standalone \
  $HL_FLAG \
  --metadata title="$(basename "$MD")" \
  $TOC_FLAG \
  --css="" \
  --include-in-header=<(cat <<'CSS'
<style>
  body { font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
         max-width: 920px; margin: 2em auto; padding: 0 1em; line-height: 1.6; }
  pre  { padding: 1em; border-radius: 6px; overflow: auto; }
  code { font-family: ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
         font-size: 0.92em; }
  nav#TOC { background: #f6f8fa; padding: 1em 1.5em; border-radius: 6px; }
</style>
CSS
  ) \
  -o "$OUTPUT"

[ ! -s "$OUTPUT" ] && { echo "ERROR: HTML not produced"; exit 1; }
```

### Step 4 — Report stats

```bash
CODE_BLOCKS=$(grep -c '<pre class="sourceCode' "$OUTPUT" 2>/dev/null || echo 0)
echo "OK $OUTPUT (${CODE_BLOCKS} highlighted blocks, $(wc -c < "$OUTPUT" | tr -d ' ') bytes)"
```

## Output Contract

```
## Markdown → Highlighted HTML

**Source:**       <md-path>
**Output:**       <html-path>
**Style:**        pygments|tango|espresso|...
**Code blocks:**  <N highlighted>
**TOC:**          included|omitted
**Size:**         <bytes>
**Method:**       pandoc --highlight-style
```

## Gotchas

- **Untagged code fences default to a generic look**: pandoc highlights based on the language hint after the opening backticks (e.g. ` ```python `). A bare ` ``` ` will not be colored. Auto-detect is **not** done.
- **Skribble inside inline code**: only fenced code blocks get colorized. Backtick-wrapped inline code stays monochrome by design.
- **`pygments` vs Python `Pygments` package**: pandoc has its own bundled highlighter. You do **not** need to `pip install pygments`. The style name `pygments` here refers to pandoc's built-in Pygments-style theme.
- **Wide code overflow**: the CSS adds `overflow: auto` so long lines scroll horizontally rather than break the layout. Don't change that without testing on mobile.
- **Empty HTML on pandoc 1.x**: very old pandoc may not support `--highlight-style` arg. Require ≥ 2.x. Check with `pandoc --version`.
- **`--highlight-style` deprecated in pandoc 3.x**: replaced by `--syntax-highlighting`. The script auto-detects which flag the installed pandoc supports.
- **Style `monokai` does NOT exist** — common confusion with editor themes. Pandoc's built-in set is exactly: `pygments tango espresso zenburn kate monochrome breezedark haddock`. Validate via `pandoc --list-highlight-styles`.
- **TOC IDs collide on duplicate headings**: pandoc appends `-1`, `-2`, etc. Anchor links in body content may break — re-check after rendering.

## Cross-Platform Notes

- Single hard dep: `pandoc`. Install via `brew install pandoc` (macOS), `apt install pandoc` (Debian/Ubuntu), `choco install pandoc` (Windows).
- `<(...)` process substitution requires bash or zsh — not POSIX `sh`. If running under `dash`, write the header CSS to a tempfile first.
- For embedded images, add `--embed-resources` (pandoc ≥ 2.18) to inline them as base64.
