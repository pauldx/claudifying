---
name: cf-tools-web-lighthouse-audit
description: "Run Google Lighthouse against a URL and report performance/accessibility/best-practices/SEO scores. Trigger: /cf-tools-web-lighthouse-audit"
trigger: /cf-tools-web-lighthouse-audit
version: 1.0.0
---

# /cf-tools-web-lighthouse-audit

Run a Lighthouse audit against any URL and report the five core category scores
(performance, accessibility, best-practices, SEO, PWA). Saves the full HTML
report alongside a parsed JSON summary so the user can dig in later.

## Usage

```
/cf-tools-web-lighthouse-audit https://example.com
/cf-tools-web-lighthouse-audit https://example.com mobile           # form factor
/cf-tools-web-lighthouse-audit https://example.com desktop ./reports
```

Arguments:
1. `url` (required) — fully-qualified URL including scheme
2. `form-factor` (optional, default `mobile`) — `mobile` | `desktop`
3. `output-dir` (optional, default `./lighthouse-<timestamp>`) — where reports land

## Install (one-time)

Lighthouse is a Node tool. Install it globally:

```bash
npm install -g lighthouse
# verify
lighthouse --version
```

Chrome (or Chromium) must also be installed — Lighthouse drives it via the
Chrome DevTools Protocol.

## What You Must Do When Invoked

### Step 1 — Verify install

```bash
if ! command -v lighthouse >/dev/null 2>&1; then
  echo "ERROR: lighthouse not installed. Run: npm install -g lighthouse"
  exit 1
fi
```

### Step 2 — Validate URL

```bash
URL="$1"
case "$URL" in
  http://*|https://*) ;;
  *) echo "ERROR: URL must include http(s):// scheme"; exit 1 ;;
esac
```

### Step 3 — Run audit

```bash
FORM="${2:-mobile}"
OUT="${3:-./lighthouse-$(date +%s)}"
mkdir -p "$OUT"

PRESET_FLAG=""
[ "$FORM" = "desktop" ] && PRESET_FLAG="--preset=desktop"

lighthouse "$URL" \
  $PRESET_FLAG \
  --quiet \
  --chrome-flags="--headless=new --no-sandbox" \
  --output=html --output=json \
  --output-path="$OUT/report"
```

Lighthouse writes `report.report.html` and `report.report.json`.

### Step 4 — Parse scores from JSON

```bash
node -e '
const r = require("'"$OUT"'/report.report.json");
const cat = r.categories;
const pct = v => v == null ? "n/a" : Math.round(v.score * 100);
console.log(JSON.stringify({
  url: r.finalDisplayedUrl,
  fetchTime: r.fetchTime,
  performance: pct(cat.performance),
  accessibility: pct(cat.accessibility),
  bestPractices: pct(cat["best-practices"]),
  seo: pct(cat.seo),
  pwa: pct(cat.pwa)
}, null, 2));'
```

Report each score with an emoji indicator: `>=90 ✅`, `50-89 ⚠️`, `<50 ❌`.

## Output Contract

```
## Lighthouse Audit

**URL:**          <final URL after redirects>
**Form factor:**  mobile | desktop
**Fetched:**      <ISO timestamp>

| Category        | Score |
|-----------------|-------|
| Performance     | XX ✅/⚠️/❌ |
| Accessibility   | XX |
| Best practices  | XX |
| SEO             | XX |
| PWA             | XX (or n/a) |

**HTML report:** <out>/report.report.html
**JSON data:**   <out>/report.report.json
```

## Gotchas

- **`lighthouse: command not found`** — global install failed silently. Re-run
  `npm install -g lighthouse` with `sudo` or fix `npm prefix` to a writable dir.
- **`Chrome not found`** — install Google Chrome or set `CHROME_PATH`. On Linux
  you may need `--chrome-flags="--no-sandbox"` (already in Step 3).
- **`ERR_CONNECTION_REFUSED` on localhost** — server isn't up. Lighthouse can't
  audit a URL that doesn't respond.
- **Mobile vs desktop scores diverge wildly** — that's expected. Mobile uses
  CPU/network throttling. Always note the form factor in reports.
- **Score is `null`** — that category was disabled or failed to run. Check the
  HTML report's "Failed audits" section.
- **Cold-cache vs warm-cache numbers vary** — run twice and report median if
  precision matters.

## Cross-Platform Notes

- **macOS / Linux**: works out of the box once `lighthouse` is on PATH.
- **CI environments**: pass `--no-sandbox` Chrome flag (already included).
  Headless Chrome needs `libnss3`, `libgbm1` on Debian/Ubuntu.
- **Windows**: install via `npm install -g lighthouse` in an admin shell; Chrome
  found automatically via registry.
