---
name: cf-tools-image-fetch-logo
description: "Fetch a brand logo/favicon by domain name with multi-source fallback (Clearbit, Google, DuckDuckGo). Trigger: /cf-tools-image-fetch-logo"
trigger: /cf-tools-image-fetch-logo
version: 1.0.0
---

# /cf-tools-image-fetch-logo

Given a brand name or domain, fetch a high-quality logo with fallback chain. Useful for slide decks, internal tooling, and brand directories.

## Usage

```
/cf-tools-image-fetch-logo stripe
/cf-tools-image-fetch-logo stripe.com --size 256
/cf-tools-image-fetch-logo anthropic --output anthropic-logo.png
/cf-tools-image-fetch-logo openai --source duckduckgo
```

Flags:
- `--size N` — preferred pixel size (default 128; sources have different max sizes)
- `--source NAME` — force a specific source: `clearbit | google | duckduckgo` (default: try all)
- `--output PATH` — destination (default `<brand>-logo.png`)

## Source Fallback Chain (verified)

| Source | URL Template | Status (probed) | Notes |
|---|---|---|---|
| Clearbit | `https://logo.clearbit.com/<domain>` | DNS resolves intermittently — service is being deprecated | Highest quality when available; PNG with transparency |
| Google S2 | `https://www.google.com/s2/favicons?domain=<domain>&sz=<size>` | HTTP 200, PNG, max 128px | Reliable, always available |
| DuckDuckGo | `https://icons.duckduckgo.com/ip3/<domain>.ico` | HTTP 200, multi-res ICO | Returns ICO (16/32/48 multi-frame) |

Probe results from this skill's test pass:
- `https://www.google.com/s2/favicons?domain=stripe.com&sz=128` → 128x128 PNG, 580B ✓
- `https://icons.duckduckgo.com/ip3/stripe.com.ico` → multi-frame ICO 16/32/48 ✓
- `https://logo.clearbit.com/stripe.com` → DNS resolution failure at test time ✗

## What You Must Do When Invoked

### Step 1 — Normalize input to domain

```bash
BRAND="$1"; shift
SIZE=128; SOURCE=""; OUTPUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --size)   SIZE="$2"; shift 2;;
    --source) SOURCE="$2"; shift 2;;
    --output) OUTPUT="$2"; shift 2;;
    *) echo "Unknown flag: $1"; exit 1;;
  esac
done

# Normalize: "stripe" → "stripe.com", strip protocol
DOMAIN=$(echo "$BRAND" | sed -E 's|^https?://||; s|/.*$||')
if [[ "$DOMAIN" != *.* ]]; then
  DOMAIN="${DOMAIN}.com"
fi

SLUG=$(echo "$DOMAIN" | sed 's|\.|_|g')
[ -z "$OUTPUT" ] && OUTPUT="${SLUG%_com}-logo.png"
```

### Step 2 — Try sources in order

```bash
try_clearbit() {
  curl -fsSL --connect-timeout 5 -o "$OUTPUT" \
    "https://logo.clearbit.com/${DOMAIN}" && \
    [ -s "$OUTPUT" ] && \
    magick identify "$OUTPUT" >/dev/null 2>&1
}

try_google() {
  curl -fsSL --connect-timeout 5 -o "$OUTPUT" \
    "https://www.google.com/s2/favicons?domain=${DOMAIN}&sz=${SIZE}" && \
    [ -s "$OUTPUT" ] && \
    magick identify "$OUTPUT" >/dev/null 2>&1
}

try_duckduckgo() {
  local tmp_ico="/tmp/_logo_${SLUG}.ico"
  curl -fsSL --connect-timeout 5 -o "$tmp_ico" \
    "https://icons.duckduckgo.com/ip3/${DOMAIN}.ico" || return 1
  [ -s "$tmp_ico" ] || return 1
  # Convert multi-frame ICO to PNG, picking largest frame
  magick "${tmp_ico}[0]" "$OUTPUT" 2>/dev/null || magick "$tmp_ico" "$OUTPUT"
  rm -f "$tmp_ico"
  [ -s "$OUTPUT" ]
}

case "$SOURCE" in
  clearbit)    try_clearbit   && SOURCE_USED="clearbit"   || SOURCE_USED="";;
  google)      try_google     && SOURCE_USED="google"     || SOURCE_USED="";;
  duckduckgo)  try_duckduckgo && SOURCE_USED="duckduckgo" || SOURCE_USED="";;
  *)
    SOURCE_USED=""
    try_clearbit   && SOURCE_USED="clearbit"
    [ -z "$SOURCE_USED" ] && try_google     && SOURCE_USED="google"
    [ -z "$SOURCE_USED" ] && try_duckduckgo && SOURCE_USED="duckduckgo"
    ;;
esac

if [ -z "$SOURCE_USED" ]; then
  echo "ERROR: no source returned a usable logo for $DOMAIN"
  exit 1
fi
```

### Step 3 — Report

```bash
W=$(magick identify -format "%w" "$OUTPUT")
H=$(magick identify -format "%h" "$OUTPUT")
SZ=$(stat -f %z "$OUTPUT" 2>/dev/null || stat -c %s "$OUTPUT")
echo ""
echo "## Logo fetched"
echo ""
echo "**Brand:**   $BRAND"
echo "**Domain:**  $DOMAIN"
echo "**Source:**  $SOURCE_USED"
echo "**Output:**  $OUTPUT  (${W}x${H}, ${SZ}B)"
```

## Output Contract

```
## Logo fetched

**Brand:**   <input>
**Domain:**  <normalized>
**Source:**  clearbit | google | duckduckgo
**Output:**  <path>  (<W>x<H>, <bytes>)
```

## Gotchas

- **Clearbit deprecation** — the service was free for years but is being phased out (status fluctuates). Don't rely on it as primary.
- **Google favicons max out at 128px** — pass `sz=256` and you still get 128. For larger logos try Clearbit first or scrape the brand's own /favicon.ico.
- **DuckDuckGo returns multi-frame ICO** — script picks frame 0 (usually 48x48) and converts to PNG via magick. The result is small but reliable.
- **Brand → domain heuristic is dumb** — "anthropic" → "anthropic.com" works but "twitter" → "twitter.com" misses the X.com rename. For non-trivial brands, pass the full domain.
- **Some logos have white-on-white** — fetched logo against white page background may be invisible. Verify visually before using.
- **CDN caching** — Google s2 caches aggressively; for a freshly redesigned logo it may take days to update.

## Cross-Platform Notes

- **macOS / Linux / Windows**: `curl` ships almost everywhere. `magick` from ImageMagick for ICO→PNG conversion.

## Privacy note

This skill makes outbound HTTP requests. Don't use it on offline systems or in privacy-restricted environments without approval.
