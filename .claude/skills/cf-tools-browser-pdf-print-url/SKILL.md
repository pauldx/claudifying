---
name: cf-tools-browser-pdf-print-url
description: "Print any URL to PDF using Chrome headless, with optional page size and header/footer suppression. Trigger: /cf-tools-browser-pdf-print-url"
trigger: /cf-tools-browser-pdf-print-url
version: 1.0.0
---

# /cf-tools-browser-pdf-print-url

Render a URL to PDF using the same engine your browser uses. Chrome's `--print-to-pdf` mode preserves CSS print styles, web fonts, and JavaScript-rendered content. Default output omits the browser's default header/footer (URL + page number) for clean docs.

## Usage

```
/cf-tools-browser-pdf-print-url <url>
/cf-tools-browser-pdf-print-url <url> /path/out.pdf
/cf-tools-browser-pdf-print-url <url> /path/out.pdf --landscape
/cf-tools-browser-pdf-print-url <url> /path/out.pdf --paper a4
/cf-tools-browser-pdf-print-url <url> /path/out.pdf --header-footer    # re-enable header/footer
```

Arguments:
1. `url` (required)
2. `output` (optional, default `/tmp/cf-pdf-<timestamp>.pdf`)
3. `--landscape` (optional) — landscape orientation
4. `--paper <letter|a4|legal>` (optional, default `letter`)
5. `--header-footer` (optional) — re-enable Chrome's default URL/page-number header/footer

## What You Must Do When Invoked

### Step 1 — Detect Chrome + parse args

```bash
detect_chrome() {
  command -v google-chrome >/dev/null 2>&1 && { echo "google-chrome"; return; }
  command -v chromium       >/dev/null 2>&1 && { echo "chromium"; return; }
  [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ] && \
    { echo "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; return; }
  echo ""
}
CHROME="$(detect_chrome)"
[ -z "$CHROME" ] && { echo "ERROR: Chrome not found"; exit 1; }

URL="$1"; OUTPUT="${2:-/tmp/cf-pdf-$(date +%s).pdf}"
LANDSCAPE_FLAG=""; PAPER="letter"; HF_FLAG="--no-pdf-header-footer"
for a in "$@"; do
  case "$a" in
    --landscape)     LANDSCAPE_FLAG="--landscape" ;;
    --header-footer) HF_FLAG="" ;;
  esac
done
# Parse --paper VALUE
prev=""; for a in "$@"; do [ "$prev" = "--paper" ] && PAPER="$a"; prev="$a"; done
```

### Step 2 — Render

```bash
"$CHROME" --headless=new --disable-gpu \
  --print-to-pdf="$OUTPUT" \
  $HF_FLAG \
  $LANDSCAPE_FLAG \
  --no-margins \
  "$URL" 2>/dev/null
```

(Chrome's PDF page size comes from CSS `@page` rules; for explicit paper size, see Gotchas.)

### Step 3 — Verify with pdfinfo

```bash
if [ -f "$OUTPUT" ] && [ -s "$OUTPUT" ]; then
  if command -v pdfinfo >/dev/null 2>&1; then
    pdfinfo "$OUTPUT" | grep -E "^(Title|Pages|Page size)"
  fi
  echo "OK $OUTPUT ($(wc -c < "$OUTPUT" | tr -d ' ') bytes)"
else
  echo "ERROR: PDF not produced"; exit 1
fi
```

## Output Contract

```
## URL → PDF

**URL:**         <url>
**Output:**      <pdf-path>
**Pages:**       <from pdfinfo>
**Page size:**   <from pdfinfo>
**Size:**        <bytes>
**Orientation:** portrait|landscape
**Method:**      Chrome --print-to-pdf
```

## Gotchas

- **Default paper is Letter**: Chrome defaults to US Letter regardless of locale. For A4, the URL itself must set `@page { size: A4 }` in its CSS, or use a wrapper HTML file. Chrome's CLI does NOT expose a `--paper-size` flag in the current `--headless=new` mode.
- **Header/footer ON by default in older Chrome**: pre-v117 used different flags. `--no-pdf-header-footer` is the current name. If your Chrome shows the URL/page number anyway, you have an old build — upgrade.
- **Background colors missing**: pass `--no-pdf-header-footer` together with `-print-backgrounds`, or add `body { -webkit-print-color-adjust: exact; }` to the page CSS.
- **Web fonts**: usually preserved, but slow networks can race the screenshot. Add `--virtual-time-budget=5000` to wait 5s for the page to settle.
- **Tall pages**: Chrome auto-paginates correctly. There's no "single page" mode — use a CSS reset on the source page if needed.
- **JS that never settles**: SPAs that poll forever will hang the print. Always use `--virtual-time-budget` (millis) for predictable runs.

## Cross-Platform Notes

- Chrome paths same as other browser skills: `/Applications/Google Chrome.app/...` on macOS, `google-chrome` or `chromium` on Linux, `chrome.exe` on Windows.
- `pdfinfo` is part of `poppler-utils` — `brew install poppler` / `apt install poppler-utils`. Optional but recommended for the verification step.
