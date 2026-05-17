---
name: cf-tools-browser-screenshot-url
description: "Capture a full-page screenshot of any URL via Chrome headless, with optional mobile viewport. Trigger: /cf-tools-browser-screenshot-url"
trigger: /cf-tools-browser-screenshot-url
version: 1.0.0
---

# /cf-tools-browser-screenshot-url

Snap a PNG of any URL using Chrome's `--screenshot` mode. Defaults to a 1280×800 desktop viewport with scrollbars hidden. Pass `--mobile` for a 390×844 (iPhone) viewport. Works on any JS-rendered page because Chrome runs the page before grabbing pixels.

## Usage

```
/cf-tools-browser-screenshot-url <url>
/cf-tools-browser-screenshot-url <url> /path/out.png
/cf-tools-browser-screenshot-url <url> /path/out.png 1920 1080
/cf-tools-browser-screenshot-url <url> /path/out.png --mobile
```

Arguments:
1. `url` (required) — fully-qualified URL (`https://...`)
2. `output` (optional, default `/tmp/cf-screenshot-<timestamp>.png`)
3. `width` (optional, default `1280`)
4. `height` (optional, default `800`)
5. `--mobile` (optional) — overrides width/height to `390x844` and adds mobile user-agent

## What You Must Do When Invoked

### Step 1 — Detect Chrome binary

```bash
detect_chrome() {
  if command -v google-chrome >/dev/null 2>&1; then echo "google-chrome"; return; fi
  if command -v google-chrome-stable >/dev/null 2>&1; then echo "google-chrome-stable"; return; fi
  if command -v chromium >/dev/null 2>&1; then echo "chromium"; return; fi
  if [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
    echo "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; return
  fi
  echo ""
}
CHROME="$(detect_chrome)"
[ -z "$CHROME" ] && { echo "ERROR: Chrome not found. Install Google Chrome or Chromium."; exit 1; }
```

### Step 2 — Parse args + render

```bash
URL="$1"
OUTPUT="${2:-/tmp/cf-screenshot-$(date +%s).png}"
WIDTH="${3:-1280}"
HEIGHT="${4:-800}"
UA_FLAG=""

# Detect --mobile flag (any position)
for a in "$@"; do
  if [ "$a" = "--mobile" ]; then
    WIDTH=390; HEIGHT=844
    UA_FLAG='--user-agent=Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
  fi
done

"$CHROME" --headless=new --disable-gpu \
  --screenshot="$OUTPUT" \
  --window-size="${WIDTH},${HEIGHT}" \
  --hide-scrollbars \
  ${UA_FLAG:+"$UA_FLAG"} \
  "$URL" 2>/dev/null
```

### Step 3 — Verify

```bash
if [ -f "$OUTPUT" ]; then
  SIZE=$(wc -c < "$OUTPUT" | tr -d ' ')
  if [ "$SIZE" -lt 5000 ]; then
    echo "WARNING: screenshot only ${SIZE}B — page may have failed to render"
  fi
  echo "OK $OUTPUT (${SIZE}B, ${WIDTH}x${HEIGHT})"
else
  echo "ERROR: screenshot not produced"; exit 1
fi
```

## Output Contract

```
## URL → Screenshot

**URL:**       <url>
**Output:**    <png-path>
**Viewport:**  <W>x<H> (mobile|desktop)
**Size:**      <KB>
**Method:**    Chrome headless
```

## Gotchas

- **Login walls / cookie banners**: Chrome headless gets the public-facing page only. No login persistence.
- **Lazy-loaded content**: Chrome doesn't scroll. Pages that load on scroll will show their above-the-fold state only.
- **Tall pages truncated**: `--screenshot` captures the viewport, not the full page height. For full-page, pass a tall `height` (e.g. `3000`).
- **Empty / tiny PNG (<5KB)**: usually means the URL 404'd or Chrome was blocked by SSL. Re-run with `--ignore-certificate-errors` flag added inside the script if testing local self-signed sites.
- **macOS `CVDisplayLinkCreateWithCGDisplay` warnings**: harmless, the file still writes.
- **Don't forget the scheme**: `example.com` without `https://` will fail. Auto-prepend if you want, but warn the user.

## Cross-Platform Notes

- **macOS**: `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`
- **Linux**: `google-chrome`, `google-chrome-stable`, or `chromium` on PATH (e.g. `apt install chromium-browser`)
- **WSL/Windows**: `chrome.exe` from `C:\Program Files\Google\Chrome\Application\` — convert path for WSL with `wslpath`.

The detection helper above tries each in order. Document this when reporting which binary was used.
