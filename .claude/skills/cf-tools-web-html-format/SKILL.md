---
name: cf-tools-web-html-format
description: "Pretty-print HTML files using tidy or prettier. Trigger: /cf-tools-web-html-format"
trigger: /cf-tools-web-html-format
version: 1.0.0
---

# /cf-tools-web-html-format

Reformat an HTML file with consistent indentation and line wrapping. Prefers
`prettier` (preserves modern HTML semantics) and falls back to `tidy` (ships on
macOS, runs everywhere). Writes formatted output in place by default; original
backed up as `<file>.bak` unless `--no-backup` is passed.

## Usage

```
/cf-tools-web-html-format ./index.html
/cf-tools-web-html-format ./index.html --no-backup
/cf-tools-web-html-format ./index.html ./formatted.html      # explicit output
```

Arguments:
1. `input` (required) — path to HTML file
2. `output` (optional) — write to a different path instead of overwriting
3. `--no-backup` (optional flag) — skip `.bak` creation

## Install

Both options below work. Try `prettier` first.

```bash
# Option A: prettier (recommended for modern HTML)
npm install -g prettier

# Option B: tidy (ships on macOS already; install on Linux)
brew install tidy-html5            # macOS Homebrew variant
sudo apt-get install -y tidy       # Debian/Ubuntu
```

## What You Must Do When Invoked

### Step 1 — Validate input

```bash
SRC="$1"
[ -f "$SRC" ] || { echo "ERROR: file not found: $SRC"; exit 1; }
case "$SRC" in
  *.html|*.htm) ;;
  *) echo "WARN: extension is not .html/.htm — continuing anyway" ;;
esac
```

### Step 2 — Backup unless suppressed

```bash
NO_BACKUP=0
for arg in "$@"; do [ "$arg" = "--no-backup" ] && NO_BACKUP=1; done
[ "$NO_BACKUP" -eq 0 ] && cp "$SRC" "$SRC.bak"
```

### Step 3 — Try prettier

```bash
OUT="${2:-$SRC}"
if command -v prettier >/dev/null 2>&1; then
  prettier --parser html --print-width 100 --tab-width 2 "$SRC" > "$OUT.tmp" \
    && mv "$OUT.tmp" "$OUT" \
    && { echo "✅ formatted via prettier → $OUT"; exit 0; }
fi
```

### Step 4 — Fallback to tidy

```bash
if command -v tidy >/dev/null 2>&1; then
  # tidy returns 1 for warnings, 2 for errors; treat 0/1 as success
  # NOTE: --drop-empty-elements only exists in tidy-html5 (brew install tidy-html5)
  #       macOS-bundled tidy (2006 build) lacks this flag — keep the call minimal.
  tidy -quiet -indent --indent-spaces 2 --wrap 100 --tidy-mark no \
       -o "$OUT.tmp" "$SRC"
  rc=$?
  if [ "$rc" -le 1 ] && [ -s "$OUT.tmp" ]; then
    mv "$OUT.tmp" "$OUT"
    echo "✅ formatted via tidy → $OUT"
    exit 0
  fi
  rm -f "$OUT.tmp"
fi

echo "ERROR: neither prettier nor tidy available. Install one:"
echo "  npm install -g prettier"
echo "  brew install tidy-html5"
exit 1
```

## Output Contract

```
## HTML formatted

**Input:**   <path>
**Output:**  <path>
**Backup:**  <path>.bak | (skipped)
**Tool:**    prettier | tidy
**Bytes:**   <before> → <after>
```

Briefly note any meaningful structural fixes tidy applied (closing tags, attr
quoting).

## Gotchas

- **macOS bundled tidy is from 2006** — `tidy --version` shows
  `released on 31 October 2006`. It works but doesn't know HTML5 elements like
  `<main>`, `<article>`, and will rewrite a `<!DOCTYPE html>` to the HTML 3.2
  doctype. `brew install tidy-html5` upgrades it and preserves the HTML5
  doctype.
- **Self-closing void tags get rewritten** — `<br/>` becomes `<br>` in tidy.
  This is HTML5-correct but may break codebases asserting XHTML.
- **Inline `<script>` content stays untouched** — neither tool formats embedded
  JS. Use `cf-tools-web-js-minify` separately if needed.
- **Empty lines collapse** — both formatters strip blank lines between tags.
  Don't use this on Liquid/Jinja templates with significant whitespace.
- **`Doctype given is "html"`** warning from tidy — harmless, that's the HTML5
  doctype.

## Cross-Platform Notes

- **macOS**: tidy preinstalled (old). `brew install tidy-html5` for HTML5
  awareness. prettier via npm.
- **Linux**: `apt-get install tidy` or `dnf install tidy`. prettier via npm.
- **Windows**: prettier via npm. Tidy: download from html-tidy.org.
