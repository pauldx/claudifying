---
name: cf-tools-web-css-minify
description: "Minify CSS files via csso or cleancss with size-savings report. Trigger: /cf-tools-web-css-minify"
trigger: /cf-tools-web-css-minify
version: 1.0.0
---

# /cf-tools-web-css-minify

Minify a CSS file and report bytes-saved. Tries `csso` first (smaller output,
structural optimizations), falls back to `cleancss`. Source map written
alongside output unless suppressed.

## Usage

```
/cf-tools-web-css-minify ./styles.css                    # → styles.min.css
/cf-tools-web-css-minify ./styles.css ./out.min.css      # explicit output
/cf-tools-web-css-minify ./styles.css --no-map           # skip source map
```

Arguments:
1. `input` (required) — path to source CSS
2. `output` (optional, default `<stem>.min.css` in same dir)
3. `--no-map` (optional flag) — skip `.map` file

## Install

```bash
# Option A: csso (recommended — structural minifier)
npm install -g csso-cli

# Option B: clean-css
npm install -g clean-css-cli
```

## What You Must Do When Invoked

### Step 1 — Validate

```bash
SRC="$1"
[ -f "$SRC" ] || { echo "ERROR: not found: $SRC"; exit 1; }
ORIG_SIZE=$(wc -c < "$SRC" | tr -d ' ')

OUT="${2:-${SRC%.css}.min.css}"
[ "$OUT" = "--no-map" ] && OUT="${SRC%.css}.min.css"

NO_MAP=0
for arg in "$@"; do [ "$arg" = "--no-map" ] && NO_MAP=1; done
```

### Step 2 — Try csso

```bash
if command -v csso >/dev/null 2>&1; then
  if [ "$NO_MAP" -eq 0 ]; then
    csso "$SRC" --output "$OUT" --source-map file
  else
    csso "$SRC" --output "$OUT"
  fi
  TOOL=csso
fi
```

### Step 3 — Fallback to cleancss

```bash
if [ -z "$TOOL" ] && command -v cleancss >/dev/null 2>&1; then
  if [ "$NO_MAP" -eq 0 ]; then
    cleancss --source-map -o "$OUT" "$SRC"
  else
    cleancss -o "$OUT" "$SRC"
  fi
  TOOL=cleancss
fi

if [ -z "$TOOL" ]; then
  echo "ERROR: install csso or clean-css:"
  echo "  npm install -g csso-cli"
  echo "  npm install -g clean-css-cli"
  exit 1
fi
```

### Step 4 — Report savings

```bash
MIN_SIZE=$(wc -c < "$OUT" | tr -d ' ')
SAVED=$((ORIG_SIZE - MIN_SIZE))
PCT=$((SAVED * 100 / ORIG_SIZE))
echo "✅ $TOOL: $ORIG_SIZE → $MIN_SIZE bytes ($PCT% saved) → $OUT"
```

## Output Contract

```
## CSS Minified

**Input:**    <path>  (<bytes>)
**Output:**   <path>  (<bytes>)
**Saved:**    <bytes> (<pct>%)
**Tool:**     csso | cleancss
**Map:**      <path>.map | (skipped)
```

## Gotchas

- **`csso` ≠ `csso-cli`** — the package name is `csso-cli` but the binary is
  `csso`. Don't `npm i -g csso` thinking that's it (that's the library only).
- **CSS variables get preserved** — both tools respect `--my-var` declarations.
- **`@import` rules not inlined by default** — pass `--restructure-off` to csso
  if you need to keep imports as-is.
- **`!important` is never stripped** — even when redundant. Both tools play it
  safe.
- **Source map paths are relative** — committed maps point at the source file's
  location at minify time. Move both together.
- **CSS with vendor prefixes (`-webkit-`, `-moz-`)** — both tools keep all
  prefixes. Use `autoprefixer` separately if you need to prune obsolete ones.

## Cross-Platform Notes

Both tools are Node-based so identical behavior across macOS / Linux / Windows.
On Apple Silicon: install Node via the universal pkg or rosetta isn't needed.
