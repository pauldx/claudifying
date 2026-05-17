---
name: cf-tools-browser-page-text
description: "Render a JS-heavy page in Chrome headless and dump the visible text. Trigger: /cf-tools-browser-page-text"
trigger: /cf-tools-browser-page-text
version: 1.0.0
---

# /cf-tools-browser-page-text

Get the plain-text content of any URL — including pages that build their DOM via JavaScript. Uses Chrome headless `--dump-dom` to obtain the post-JS HTML, then strips tags via pandoc (preferred) or a Python BeautifulSoup-style fallback.

This is different from `curl <url>` because most modern sites return empty `<div id=root>` shells that only render text after JS execution.

## Usage

```
/cf-tools-browser-page-text <url>
/cf-tools-browser-page-text <url> /path/out.txt
/cf-tools-browser-page-text <url> --raw          # keep newlines/spacing
```

Arguments:
1. `url` (required)
2. `output` (optional, default stdout; pass file path to write)
3. `--raw` (optional) — preserve original whitespace and line breaks instead of squeezing

## What You Must Do When Invoked

### Step 1 — Detect Chrome (same helper as screenshot-url)

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
```

### Step 2 — Dump rendered DOM, strip to text

```bash
URL="$1"
OUTPUT="${2:-}"
RAW=0; for a in "$@"; do [ "$a" = "--raw" ] && RAW=1; done

HTML=$("$CHROME" --headless=new --disable-gpu --dump-dom "$URL" 2>/dev/null)

# Strip HTML → text. Pandoc preferred (cleaner output).
if command -v pandoc >/dev/null 2>&1; then
  TEXT=$(echo "$HTML" | pandoc -f html -t plain --wrap=preserve)
else
  # Python fallback uses html.parser stdlib only — no third-party deps
  TEXT=$(echo "$HTML" | python3 -c '
import sys, re, html
from html.parser import HTMLParser
class S(HTMLParser):
    def __init__(self): super().__init__(); self.out=[]; self.skip=0
    def handle_starttag(self, t, a):
        if t in ("script","style","noscript"): self.skip += 1
    def handle_endtag(self, t):
        if t in ("script","style","noscript"): self.skip = max(0, self.skip-1)
        if t in ("p","div","br","li","h1","h2","h3","h4","tr"): self.out.append("\n")
    def handle_data(self, d):
        if not self.skip: self.out.append(d)
p = S(); p.feed(sys.stdin.read())
print(re.sub(r"\n{3,}", "\n\n", "".join(p.out)).strip())
')
fi

[ "$RAW" -eq 0 ] && TEXT=$(echo "$TEXT" | awk 'NF' | sed 's/[[:space:]]\+/ /g')

if [ -n "$OUTPUT" ]; then
  echo "$TEXT" > "$OUTPUT"
  echo "OK $OUTPUT ($(wc -c < "$OUTPUT" | tr -d ' ') bytes)"
else
  echo "$TEXT"
fi
```

## Output Contract

If `output` given:
```
## URL → Text

**URL:**     <url>
**Output:**  <txt-path>
**Bytes:**   <n>
**Method:**  Chrome --dump-dom + pandoc|python
```
If not, plain text printed to stdout, framed with a single header line `--- <url> ---`.

## Gotchas

- **Tag stripping leaves giant blank gaps**: keep the default (non-raw) mode; `--raw` is for layout-sensitive content like ASCII art.
- **`<script>` content leaks through**: pandoc handles this; the Python fallback also skips `script`/`style`/`noscript`.
- **Login walls return login text**: same caveat as screenshot — no session, no cookies.
- **Very long pages**: this prints everything. For long pages, redirect to a file and grep, don't dump to terminal.
- **HTML entities (`&amp;`, `&#x27;`)**: pandoc decodes them. The Python fallback uses `html.unescape` if you add it to `handle_data`.
- **Pandoc errors on malformed HTML**: rare; the Python fallback is the safety net. Add `--mathjax` flag if pages have inline math you want preserved.

## Cross-Platform Notes

- macOS / Linux: pandoc is the cleanest path (`brew install pandoc` / `apt install pandoc`).
- WSL: works the same once `chrome.exe` is on PATH or invoked via `wslpath`.
- The Python fallback uses only stdlib (`html.parser`), so no `pip install` ever required.
