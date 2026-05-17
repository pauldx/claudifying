---
name: cf-tools-md-to-slides
description: "Convert Markdown to reveal.js HTML slides via pandoc. Trigger: /cf-tools-md-to-slides"
trigger: /cf-tools-md-to-slides
version: 1.0.0
---

# /cf-tools-md-to-slides

Convert a Markdown file to a self-contained reveal.js HTML slideshow using pandoc. Each H1 (or H2, depending on `--slide-level`) becomes a slide. Optional themes, transitions, and speaker notes.

## Usage

```
/cf-tools-md-to-slides input.md                                      # → input.html
/cf-tools-md-to-slides input.md deck.html
/cf-tools-md-to-slides input.md deck.html --theme black              # built-in theme
/cf-tools-md-to-slides input.md deck.html --slide-level 1            # H1 = new slide
/cf-tools-md-to-slides input.md deck.html --transition fade
/cf-tools-md-to-slides input.md deck.html --embed                    # inline everything (offline-ready)
```

Arguments:
1. `md-path` (required)
2. `out-path` (optional, default `<stem>.html`)
3. `--theme name` — reveal.js theme: `black | white | league | beige | sky | night | serif | simple | solarized | moon | dracula | blood`
4. `--slide-level N` — heading level that creates a new slide (default 2 = H2)
5. `--transition style` — `none | fade | slide | convex | concave | zoom`
6. `--embed` — inline reveal.js, CSS, and images (works offline)

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
THEME="black"
SLIDE_LEVEL="2"
TRANSITION="slide"
EMBED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --theme) THEME="$2"; shift 2 ;;
    --slide-level) SLIDE_LEVEL="$2"; shift 2 ;;
    --transition) TRANSITION="$2"; shift 2 ;;
    --embed) EMBED=1; shift ;;
    -*) shift ;;
    *) [ -z "$OUT_PATH" ] && OUT_PATH="$1"; shift ;;
  esac
done

[ ! -f "$MD_PATH" ] && { echo "ERROR: not found: $MD_PATH" >&2; exit 1; }
[ -z "$OUT_PATH" ] && OUT_PATH="${MD_PATH%.md}.html"
```

### Step 3 — Build and run

```bash
CMD=(pandoc -t revealjs --standalone \
     --slide-level="$SLIDE_LEVEL" \
     -V theme="$THEME" \
     -V transition="$TRANSITION" \
     -V revealjs-url="https://unpkg.com/reveal.js@4")

[ "$EMBED" = "1" ] && CMD+=(--embed-resources)

CMD+=(-o "$OUT_PATH" "$MD_PATH")

echo "Running: ${CMD[*]}" >&2
"${CMD[@]}"
```

### Step 4 — Report

```bash
if [ -f "$OUT_PATH" ]; then
  BYTES=$(wc -c < "$OUT_PATH" | tr -d ' ')
  SLIDES=$(grep -c '<section' "$OUT_PATH" 2>/dev/null || echo "?")
  echo "✅ slides written → $OUT_PATH ($BYTES bytes, ~$SLIDES sections)" >&2
  echo "   Open in browser; press 's' for speaker notes, 'esc' for overview" >&2
fi
```

## Markdown conventions for slides

- **Slide separator**: heading at `--slide-level` (default H2 = `##`).
- **Nested vertical slides**: heading one level deeper creates a vertical sub-slide.
- **Speaker notes**:
  ```markdown
  ## My Slide

  Visible bullet point

  ::: notes
  These notes only show in speaker view (press 's').
  :::
  ```
- **Fragments** (progressive reveal):
  ```markdown
  - First {.fragment}
  - Second {.fragment}
  ```
- **Custom slide background**:
  ```markdown
  ## Slide title {data-background-color="#1a1a1a"}
  ```

## Alternative tool — reveal-md

For a watch-and-reload dev experience, install `reveal-md`:

```bash
npm install -g reveal-md
reveal-md input.md                       # opens browser, live reload on save
reveal-md input.md --static dist/        # build static deck
reveal-md input.md --theme black.css --print deck.pdf   # export to PDF
```

`reveal-md` is friendlier for live editing. `pandoc -t revealjs` is friendlier for build pipelines and CI.

## Output Contract

```
## Markdown → reveal.js slides

**Source:**      <md-path>
**Output:**      <html-path>
**Theme:**       <theme>
**Slide level:** H<N>
**Transition:**  <style>
**Embedded:**    yes | no
**Size:**        <bytes / KB>
```

## Gotchas

- **`--slide-level=2` is the default** — H1 is treated as a section title (a "title slide" pseudo), H2 as a new slide. Set `--slide-level=1` if you want every `#` to be a fresh slide.
- **`revealjs-url`** defaults to a CDN. For offline use, pass `--embed-resources` (pandoc 3+) or download reveal.js locally and point `revealjs-url` at the local copy.
- **Code highlighting in slides** — pandoc uses skylighting by default; reveal.js's highlight plugin only loads if you provide a custom template that includes it. Use `--highlight-style=tango` for inline pandoc highlighting.
- **Math**: add `--mathjax` for `$...$` rendering inside slides.
- **Image paths**: relative paths break unless `--embed-resources` is used or images sit alongside the HTML.
- **Print to PDF**: open the deck with `?print-pdf` appended to the URL, then Chrome → Print → Save as PDF.
- **Pandoc 2.x flag is `--self-contained`**, renamed to `--embed-resources` in 3.0. If on 2.x, change the flag.
- **Speaker view**: opens in a second window; require popup permission on the browser.

## Cross-Platform Notes

- **macOS**: `brew install pandoc`. `npm install -g reveal-md` for the live-reload alternative.
- **Linux**: `apt install pandoc`. `reveal-md` via npm.
- **Windows**: `choco install pandoc` + npm.
