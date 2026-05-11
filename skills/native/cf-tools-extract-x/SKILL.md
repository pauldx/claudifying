---
name: tools-extract-x
description: "Extract full content from X.com (Twitter) posts and threads — text, author, date, media descriptions — without requiring browser auth. Uses oEmbed API + fallback chain. Trigger: /tool-extract-x <url>"
trigger: /tool-extract-x
version: 1.0.0
---

# /tool-extract-x

Extract structured content from any X.com (Twitter) post or thread. No browser auth required. Works in any project.

## Usage

```
/tool-extract-x https://x.com/username/status/123456789
/tool-extract-x https://twitter.com/username/status/123456789
```

## What You Must Do When Invoked

The input is an X.com or twitter.com URL. Execute these steps in order.

### Step 1 — Normalize the URL

Accept either `x.com` or `twitter.com` URLs. Both work identically. Extract the status ID from the URL path.

```bash
TWEET_URL="<url-from-user>"
# Normalize: replace x.com with twitter.com for oEmbed compatibility
NORMALIZED=$(echo "$TWEET_URL" | sed 's|x\.com|twitter.com|g')
STATUS_ID=$(echo "$TWEET_URL" | grep -oP '/status/\K[0-9]+')
echo "Status ID: $STATUS_ID"
echo "Normalized URL: $NORMALIZED"
```

### Step 2 — Fetch via oEmbed API (primary method)

Twitter's oEmbed API is public, requires no auth, and returns tweet text + author + date:

```bash
OEMBED_RESPONSE=$(curl -sL "https://publish.twitter.com/oembed?url=${NORMALIZED}&maxwidth=550&omit_script=true" 2>&1)
echo "$OEMBED_RESPONSE"
```

Parse from the JSON response:
- `author_name` → who posted
- `author_url` → profile link  
- `html` → contains tweet text (between `<p>` tags, before `</p>`)
- `url` → canonical URL
- The `html` field may truncate long tweets with `…` — note this if present

Extract clean text from HTML:
```bash
TWEET_TEXT=$(echo "$OEMBED_RESPONSE" | python3 -c "
import json, sys, html, re
data = json.load(sys.stdin)
raw_html = data.get('html', '')
# Strip HTML tags
text = re.sub(r'<[^>]+>', ' ', raw_html)
# Decode HTML entities
text = html.unescape(text)
# Collapse whitespace
text = re.sub(r'\s+', ' ', text).strip()
print(text)
" 2>/dev/null || echo "$OEMBED_RESPONSE" | grep -oP '(?<=<p)[^>]*>.*?(?=</p>)' | head -1)
echo "Extracted text: $TWEET_TEXT"
```

### Step 3 — Detect truncation and fetch thread (if needed)

oEmbed truncates threads and long tweets with `…`. Check for truncation:

```bash
IS_TRUNCATED=$(echo "$OEMBED_RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
html = data.get('html', '')
print('yes' if '…' in html or '&#8230;' in html else 'no')
" 2>/dev/null || echo "unknown")
echo "Truncated: $IS_TRUNCATED"
```

If truncated, try fetching the Wayback Machine snapshot for full text:

```bash
WAYBACK_URL="https://web.archive.org/web/*/${NORMALIZED}"
WAYBACK_RESULT=$(curl -sL --max-time 8 "https://archive.org/wayback/available?url=${NORMALIZED}" 2>&1)
echo "Wayback check: $WAYBACK_RESULT"
```

If Wayback has a snapshot, fetch it:
```bash
SNAPSHOT_URL=$(echo "$WAYBACK_RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
snap = data.get('archived_snapshots', {}).get('closest', {})
print(snap.get('url', '')) if snap.get('available') else print('')
" 2>/dev/null)

if [ -n "$SNAPSHOT_URL" ]; then
  SNAPSHOT_CONTENT=$(curl -sL --max-time 10 "$SNAPSHOT_URL" 2>&1 | \
    grep -oP '(?<=lang="en" dir="ltr">).*?(?=<a href)' | head -3)
  echo "Snapshot content: $SNAPSHOT_CONTENT"
fi
```

### Step 4 — Check for image/media in tweet

The oEmbed HTML contains `pic.twitter.com/` short URLs for media. Extract and expand them:

```bash
MEDIA_URLS=$(echo "$OEMBED_RESPONSE" | grep -oP 'pic\.twitter\.com/\w+' | head -5)
if [ -n "$MEDIA_URLS" ]; then
  echo "Media found: $MEDIA_URLS"
  for SHORT_URL in $MEDIA_URLS; do
    EXPANDED=$(curl -sIL --max-time 5 "https://$SHORT_URL" 2>&1 | grep -i '^location:' | tail -1 | tr -d '\r')
    echo "  $SHORT_URL → $EXPANDED"
  done
fi
```

If the user provided a screenshot image alongside the URL (Image attachment in chat), read it directly using the Read tool — it may contain the full tweet text or infographic.

### Step 5 — Assemble and output structured result

After all fetch attempts, output a structured summary:

```
## X Post Extracted

**Author:** [author_name] (@handle)
**Date:** [date from oEmbed]
**URL:** [canonical URL]
**Status ID:** [id]

**Text:**
[full tweet text — mark "[TRUNCATED]" if oEmbed cut it off]

**Media:** [list any pic.twitter.com URLs found, or "none"]

**Thread:** [if this is part of a thread, note it — oEmbed only returns the quoted tweet, not replies]

**Extraction method:** oEmbed API [+ Wayback snapshot if used]
```

### Step 6 — Handle failures gracefully

If oEmbed returns a 402/403/404:
- Status 402/403: X has rate-limited or paywalled this endpoint
- Status 404: tweet deleted or URL wrong
- Timeout: X infrastructure issue

Fallback chain in order:
1. `curl` with Twitterbot user-agent: `curl -sL -A "Twitterbot/1.0" "<url>"`
2. Nitter public instances (try in order, stop at first success):
   ```bash
   for HOST in nitter.net nitter.it nitter.poast.org nitter.1d4.us nitter.privacydev.net; do
     RESULT=$(curl -sL --max-time 6 "https://$HOST/$(echo $TWEET_URL | grep -oP '(?<=x\.com/).*')" 2>&1)
     if echo "$RESULT" | grep -q 'tweet-content'; then
       echo "=== Success via $HOST ==="
       echo "$RESULT" | grep -oP '(?<=tweet-content[^>]*>)[^<]+' | head -5
       break
     fi
   done
   ```
3. Wayback Machine snapshot (Step 3 above)
4. Tell user: "X requires authentication for this post. Please paste the text or share a screenshot."

### Error messages to show user

| Situation | What to say |
|-----------|-------------|
| All methods fail | "Could not fetch this post automatically. Please paste the tweet text or share a screenshot." |
| Partial content only | "Fetched partial content (tweet truncated by API). Thread continuation not available — paste remaining tweets if needed." |
| Deleted tweet | "This tweet appears to have been deleted (404). Try the Wayback Machine: `https://web.archive.org/web/*/[url]`" |

## Output Contract

After extraction, always return:
1. The structured result block (Step 5 format)
2. A note on what was and wasn't retrievable
3. Offer next action: "Want me to write an article, summary, or SCQA from this content?"

## Notes

- oEmbed API is public and requires no API key — most reliable method
- Nitter instances go up and down; try multiple before giving up
- Threads (reply chains by same author) are NOT returned by oEmbed — each tweet in a thread needs a separate fetch by status ID
- Images in tweets are served from `pbs.twimg.com` — not directly fetchable without auth, but describable if user shares screenshot
- The `pic.twitter.com/XXXXX` short URLs redirect to `twitter.com/status/ID/photo/N` — they don't expose the CDN URL directly
