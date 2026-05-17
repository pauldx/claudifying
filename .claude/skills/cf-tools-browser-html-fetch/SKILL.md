---
name: cf-tools-browser-html-fetch
description: "Fetch raw HTML from a URL via curl and save to file, with optional tidy pretty-print. Trigger: /cf-tools-browser-html-fetch"
trigger: /cf-tools-browser-html-fetch
version: 1.0.0
---

# /cf-tools-browser-html-fetch

GET an HTTP(S) URL with `curl`, save the raw HTML response to disk, and optionally run it through `tidy` for human-readable indentation. This is the **non-JS** counterpart to `cf-tools-browser-page-text` — fast, no Chrome boot, but only sees the server-rendered HTML.

## Usage

```
/cf-tools-browser-html-fetch <url>
/cf-tools-browser-html-fetch <url> /path/out.html
/cf-tools-browser-html-fetch <url> /path/out.html --pretty
/cf-tools-browser-html-fetch <url> /path/out.html --pretty --ua mobile
```

Arguments:
1. `url` (required)
2. `output` (optional, default `/tmp/cf-html-<timestamp>.html`)
3. `--pretty` (optional) — run through `tidy -i -q` for indentation
4. `--ua <desktop|mobile|bot>` (optional, default `desktop`) — sets common User-Agent

## What You Must Do When Invoked

### Step 1 — Parse args + select UA

```bash
URL="$1"
OUTPUT="${2:-/tmp/cf-html-$(date +%s).html}"
PRETTY=0; UA="desktop"
shift 2 2>/dev/null
while [ $# -gt 0 ]; do
  case "$1" in
    --pretty) PRETTY=1 ;;
    --ua) UA="$2"; shift ;;
  esac
  shift
done

case "$UA" in
  mobile)  AGENT='Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1' ;;
  bot)     AGENT='Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)' ;;
  *)       AGENT='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36' ;;
esac
```

### Step 2 — Fetch with curl, follow redirects, time it

```bash
curl -sSL \
  --max-time 30 \
  --user-agent "$AGENT" \
  --compressed \
  -w "HTTP %{http_code} | %{size_download} bytes | %{time_total}s | final-url=%{url_effective}\n" \
  -o "$OUTPUT" \
  "$URL"

if [ ! -s "$OUTPUT" ]; then
  echo "ERROR: empty response from $URL"; exit 1
fi
```

### Step 3 — Optional pretty-print

```bash
if [ "$PRETTY" -eq 1 ]; then
  if command -v tidy >/dev/null 2>&1; then
    tidy -i -q -wrap 120 --tidy-mark no -o "$OUTPUT.tidy" "$OUTPUT" 2>/dev/null
    mv "$OUTPUT.tidy" "$OUTPUT"
    echo "Pretty-printed via tidy"
  elif command -v prettier >/dev/null 2>&1; then
    prettier --write --parser html "$OUTPUT" >/dev/null 2>&1
    echo "Pretty-printed via prettier"
  else
    echo "WARNING: --pretty requested but neither tidy nor prettier found"
  fi
fi
echo "OK $OUTPUT ($(wc -c < "$OUTPUT" | tr -d ' ') bytes)"
```

## Output Contract

```
## URL → HTML

**URL:**       <url>
**Final URL:** <after-redirects>
**Status:**    <HTTP code>
**Output:**    <html-path>
**Size:**      <bytes>
**Time:**      <seconds>
**Pretty:**    yes|no (tidy|prettier)
**UA:**        desktop|mobile|bot
```

## Gotchas

- **JS-only sites return shells**: if the body is `<div id="root"></div>` plus scripts, the site is client-rendered. Use `/cf-tools-browser-page-text` instead.
- **403 Forbidden**: many sites block default `curl` UA. The skill always sends a desktop UA, but Cloudflare / Akamai may still challenge. Try `--ua bot` (some sites whitelist Googlebot) or fall back to Chrome headless.
- **Compression**: `--compressed` requested. If your curl is too old to support brotli, the server may serve uncompressed.
- **Cookies / login**: not persisted. Use `curl -b cookies.txt` manually for authenticated fetches.
- **Tidy noise**: `tidy` warns about every HTML5 element it doesn't know. `-q` quiets that. Don't strip `--show-warnings no` from older tidy versions.
- **Output already exists**: this overwrites without prompting. Pass a unique filename if that matters.

## Cross-Platform Notes

- `curl` ships with macOS and most Linux distros. `tidy` is `brew install tidy-html5` on macOS, `apt install tidy` on Debian/Ubuntu.
- `prettier` (Node) is the fallback formatter — install with `npm i -g prettier`.
- Windows: prefer `curl.exe` in PowerShell over the alias `Invoke-WebRequest`.
