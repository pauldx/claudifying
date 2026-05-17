---
name: cf-tools-md-to-html
description: "Convert Markdown to standalone HTML5 via pandoc. Trigger: /cf-tools-md-to-html"
trigger: /cf-tools-md-to-html
version: 1.0.0
---

# /cf-tools-md-to-html

Convert a Markdown file to an HTML5 document. Uses `pandoc` (3.x+) with `--standalone` so the output includes `<!doctype html>`, `<head>`, and optional CSS. Supports syntax highlighting and a custom stylesheet.

## Usage

```
/cf-tools-md-to-html input.md                                  # → input.html, default style
/cf-tools-md-to-html input.md out.html
/cf-tools-md-to-html input.md out.html --css style.css         # link to external CSS
/cf-tools-md-to-html input.md out.html --highlight tango       # code highlight theme
/cf-tools-md-to-html input.md out.html --no-toc                # skip table of contents
/cf-tools-md-to-html input.md out.html --template mytmpl.html  # custom pandoc template
```

Arguments:
1. `md-path` (required) — markdown file
2. `out-path` (optional, default `<stem>.html`)
3. `--css path` — link to external CSS (multiple flags allowed)
4. `--highlight style` — `pygments | tango | espresso | zenburn | kate | monochrome | breezedark | haddock`
5. `--no-toc` — disable auto ToC
6. `--template path` — pandoc HTML template

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
CSS_ARGS=()
HIGHLIGHT="pygments"
TOC_FLAG="--toc"
TEMPLATE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --css) CSS_ARGS+=(--css "$2"); shift 2 ;;
    --highlight) HIGHLIGHT="$2"; shift 2 ;;
    --no-toc) TOC_FLAG=""; shift ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    -*) shift ;;
    *) [ -z "$OUT_PATH" ] && OUT_PATH="$1"; shift ;;
  esac
done

[ ! -f "$MD_PATH" ] && { echo "ERROR: not found: $MD_PATH" >&2; exit 1; }
[ -z "$OUT_PATH" ] && OUT_PATH="${MD_PATH%.md}.html"
```

### Step 3 — Build pandoc command

```bash
CMD=(pandoc -f gfm -t html5 --standalone \
     --highlight-style="$HIGHLIGHT" \
     --metadata title="$(basename "$MD_PATH" .md)")

[ -n "$TOC_FLAG" ] && CMD+=("$TOC_FLAG" --toc-depth=3)
[ ${#CSS_ARGS[@]} -gt 0 ] && CMD+=("${CSS_ARGS[@]}")
[ -n "$TEMPLATE" ] && CMD+=(--template "$TEMPLATE")

CMD+=(-o "$OUT_PATH" "$MD_PATH")

echo "Running: ${CMD[*]}" >&2
"${CMD[@]}"
```

### Step 4 — Report

```bash
if [ -f "$OUT_PATH" ]; then
  BYTES=$(wc -c < "$OUT_PATH" | tr -d ' ')
  LINES=$(wc -l < "$OUT_PATH" | tr -d ' ')
  echo "✅ HTML written → $OUT_PATH ($BYTES bytes, $LINES lines)" >&2
fi
```

## Notes on pandoc flags used

- **`-f gfm`** — GitHub-Flavored Markdown reader (tables, task lists, fenced code, autolinks).
- **`-t html5`** — modern HTML5 writer.
- **`--standalone`** — emit a full document with `<head>`, not a fragment.
- **`--highlight-style=pygments`** — built-in highlight themes; no extra install.
- **`--toc --toc-depth=3`** — pandoc emits a ToC of H1..H3 inside `<nav id="TOC">`.
- **`--metadata title=...`** — fills `<title>` tag (otherwise pandoc warns).

## Output Contract

```
## Markdown → HTML

**Source:**     <md-path>
**Output:**     <html-path>
**Highlight:**  <style>
**TOC:**        included (depth 3) | skipped
**CSS:**        <list or default>
**Size:**       <bytes / KB>
```

## Gotchas

- **`pandoc -f markdown` vs `-f gfm`** — plain `markdown` is pandoc's superset (includes citation, footnotes, definition lists). `gfm` is stricter and matches GitHub rendering. Use whichever your source targets.
- **Title metadata** — without `--metadata title=...` or a frontmatter `title:` field, pandoc warns and emits an empty `<title>`. Set it explicitly.
- **Code highlighting**: `--highlight-style` accepts a built-in name OR a path to a `.theme` file. `--no-highlight` disables it (smaller output).
- **External CSS links** are `<link rel="stylesheet" href="...">`. For embedded styles use `--include-in-header=<(echo '<style>...</style>')`.
- **Math** rendering: add `--mathjax` or `--katex` to enable LaTeX math output. Otherwise `$x^2$` becomes literal text.
- **Tables**: pandoc reads GFM pipe tables natively. Wide tables get a horizontal scroll if you add `table { display: block; overflow-x: auto; }` to your CSS.
- **Self-contained**: add `--embed-resources --standalone` to inline images and CSS as data URIs (great for email-friendly single-file HTML).
- **Pandoc 3.0+** — `--self-contained` was renamed to `--embed-resources`. If on pandoc 2.x, swap the flag.

## Cross-Platform Notes

- **macOS**: `brew install pandoc` (currently 3.9+).
- **Linux**: `apt install pandoc`, or download .deb from `https://github.com/jgm/pandoc/releases` for the newest version.
- **Windows**: `choco install pandoc` or .msi from the releases page.
