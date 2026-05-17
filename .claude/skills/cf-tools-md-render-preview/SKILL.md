---
name: cf-tools-md-render-preview
description: "Render a Markdown file to standalone HTML with GitHub-style CSS and optionally open in browser. Trigger: /cf-tools-md-render-preview"
trigger: /cf-tools-md-render-preview
version: 1.0.0
---

# /cf-tools-md-render-preview

Convert a Markdown file to a self-contained HTML preview using pandoc, styled with GitHub-flavored CSS. By default opens the result in the user's default browser; pass `--no-open` for headless environments (CI, SSH).

This is the "fast eyeball" preview — for production HTML use `/cf-tools-md-to-html` (which has more knobs).

## Usage

```
/cf-tools-md-render-preview <markdown-file>
/cf-tools-md-render-preview <markdown-file> /path/out.html
/cf-tools-md-render-preview <markdown-file> /path/out.html --no-open
/cf-tools-md-render-preview <markdown-file> /path/out.html --theme dark
```

Arguments:
1. `markdown-file` (required) — absolute or relative `.md` path
2. `output` (optional, default `<md-stem>.preview.html` next to source)
3. `--no-open` (optional) — don't fire `open` / `xdg-open` after writing
4. `--theme <light|dark>` (optional, default `light`)

## What You Must Do When Invoked

### Step 1 — Validate input

```bash
MD="$1"
[ ! -f "$MD" ] && { echo "ERROR: $MD not found"; exit 1; }
OUTPUT="${2:-${MD%.md}.preview.html}"

NO_OPEN=0; THEME="light"
for a in "$@"; do [ "$a" = "--no-open" ] && NO_OPEN=1; done
prev=""; for a in "$@"; do [ "$prev" = "--theme" ] && THEME="$a"; prev="$a"; done
```

### Step 2 — Build inline CSS (GitHub-style)

```bash
# Use a heredoc into a temp CSS file so pandoc can inline it.
CSS=$(mktemp -t cf-md-XXXXXX.css)
if [ "$THEME" = "dark" ]; then
  cat > "$CSS" <<'CSS_EOF'
body { font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
       max-width: 880px; margin: 2em auto; padding: 0 1em;
       background: #0d1117; color: #e6edf3; line-height: 1.6; }
h1,h2,h3 { border-bottom: 1px solid #30363d; padding-bottom: .3em; }
code { background: #161b22; padding: .2em .4em; border-radius: 4px; }
pre  { background: #161b22; padding: 1em; border-radius: 6px; overflow: auto; }
pre code { background: transparent; padding: 0; }
a { color: #58a6ff; }
blockquote { color: #8b949e; border-left: .25em solid #30363d; padding: 0 1em; }
table { border-collapse: collapse; }
th, td { border: 1px solid #30363d; padding: .4em .8em; }
CSS_EOF
else
  cat > "$CSS" <<'CSS_EOF'
body { font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
       max-width: 880px; margin: 2em auto; padding: 0 1em;
       color: #1f2328; line-height: 1.6; }
h1,h2,h3 { border-bottom: 1px solid #d0d7de; padding-bottom: .3em; }
code { background: #f6f8fa; padding: .2em .4em; border-radius: 4px; }
pre  { background: #f6f8fa; padding: 1em; border-radius: 6px; overflow: auto; }
pre code { background: transparent; padding: 0; }
a { color: #0969da; }
blockquote { color: #59636e; border-left: .25em solid #d0d7de; padding: 0 1em; }
table { border-collapse: collapse; }
th, td { border: 1px solid #d0d7de; padding: .4em .8em; }
CSS_EOF
fi
```

### Step 3 — Render with pandoc

```bash
# Detect pandoc flag generation (3.x uses --embed-resources + --syntax-highlighting,
# 2.x uses --self-contained + --highlight-style). Probe once.
if pandoc --help 2>&1 | grep -q -- "--embed-resources"; then
  EMBED_FLAG="--embed-resources --standalone"
else
  EMBED_FLAG="--self-contained"
fi
if pandoc --help 2>&1 | grep -q -- "--syntax-highlighting"; then
  HL_FLAG="--syntax-highlighting=pygments"
else
  HL_FLAG="--highlight-style=pygments"
fi

pandoc "$MD" \
  $EMBED_FLAG \
  --metadata title="$(basename "$MD")" \
  --css="$CSS" \
  $HL_FLAG \
  -o "$OUTPUT" 2>/dev/null \
  || pandoc "$MD" --standalone --metadata title="$(basename "$MD")" \
       --css="$CSS" $HL_FLAG -o "$OUTPUT"
# Fallback above writes a non-embedded version that still works locally.

rm -f "$CSS"

[ ! -s "$OUTPUT" ] && { echo "ERROR: HTML not produced"; exit 1; }
echo "Wrote $OUTPUT ($(wc -c < "$OUTPUT" | tr -d ' ') bytes)"
```

### Step 4 — Optionally open

```bash
if [ "$NO_OPEN" -eq 0 ]; then
  case "$(uname -s)" in
    Darwin) open "$OUTPUT" ;;
    Linux)  command -v xdg-open >/dev/null && xdg-open "$OUTPUT" >/dev/null 2>&1 & ;;
    *)      echo "No GUI opener detected; pass --no-open to suppress this message" ;;
  esac
fi
```

## Output Contract

```
## Markdown → HTML preview

**Source:**  <md-path>
**Output:**  <html-path>
**Theme:**   light|dark
**Opened:**  yes|no
**Size:**    <bytes>
**Method:**  pandoc --standalone
```

## Gotchas

- **`--self-contained` deprecated in pandoc 3.x**: replaced by `--embed-resources --standalone`. The script tries the modern flag first, falls back to the legacy.
- **Images won't embed without `--embed-resources`**: external images will broken-link if you move the HTML elsewhere. For portability use that flag explicitly.
- **Headless context auto-`open`**: in SSH/CI the `open` command may freeze or open the wrong place. Always pass `--no-open` when calling from CI.
- **GitHub Flavored Markdown extras**: pandoc supports task lists, tables, fenced code by default. For strict GFM, add `-f gfm`.
- **`pygments` not installed**: pandoc will warn and emit unhighlighted code. Install with `pip install pygments` or switch to `--highlight-style tango` (pure pandoc).
- **Dark theme + system theme mismatch**: this writes a static CSS — it does not respect `prefers-color-scheme`. Re-run with the other theme if needed.

## Cross-Platform Notes

- `pandoc` is the only hard dep: `brew install pandoc` / `apt install pandoc` / `choco install pandoc`.
- `open` / `xdg-open` for the browser hand-off; pair with `/cf-tools-browser-open-url` for finer browser control.
- For batch previews, loop and pass `--no-open` to avoid stacking N browser windows.
