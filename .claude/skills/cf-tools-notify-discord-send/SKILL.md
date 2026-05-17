---
name: cf-tools-notify-discord-send
description: "Post messages to Discord via webhook with optional embeds. Trigger: /cf-tools-notify-discord-send"
trigger: /cf-tools-notify-discord-send
version: 1.0.0
---

# /cf-tools-notify-discord-send

Send messages to a Discord channel via incoming webhook. Supports plain text, rich embeds, and file uploads.

## Usage

```
/cf-tools-notify-discord-send "Build green :white_check_mark:"
/cf-tools-notify-discord-send --file release-notes.md
/cf-tools-notify-discord-send --embed embed.json
/cf-tools-notify-discord-send --username "DeployBot" --avatar-url https://… "Shipped v1.2.0"
```

Arguments:
1. `message` (positional, optional) — plain text body (max 2000 chars)
2. `--file <path>` — read message body from file
3. `--embed <path>` — Discord embed JSON (single object or array; max 10 embeds)
4. `--username <name>` — display name override
5. `--avatar-url <url>` — avatar override
6. `--tts` — text-to-speech flag
7. `--attach <path>` — upload a file (uses multipart/form-data)

## Credentials (env var only)

```bash
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/<id>/<token>"
```

> Webhook URL must come from env. Never accept as CLI arg.

## What You Must Do When Invoked

### Step 1 — Validate env

```bash
set +x  # NEVER xtrace — DISCORD_WEBHOOK_URL contains a secret token

if [ -z "$DISCORD_WEBHOOK_URL" ]; then
  echo "ERROR: export DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/..."
  exit 1
fi
```

### Step 2 — Build payload

```bash
if [ -n "$FILE" ]; then
  CONTENT=$(cat "$FILE")
else
  CONTENT="$MESSAGE"
fi

# Embeds override or augment content
if [ -n "$EMBED_FILE" ]; then
  EMBED_JSON=$(cat "$EMBED_FILE")
  # Normalize: wrap single object in array
  if echo "$EMBED_JSON" | jq -e 'type == "object"' >/dev/null; then
    EMBED_JSON="[$EMBED_JSON]"
  fi
  PAYLOAD=$(jq -n \
    --arg content "$CONTENT" \
    --argjson embeds "$EMBED_JSON" \
    '{content: $content, embeds: $embeds}')
else
  PAYLOAD=$(jq -n --arg content "$CONTENT" '{content: $content}')
fi

[ -n "$USERNAME" ]   && PAYLOAD=$(echo "$PAYLOAD" | jq --arg u "$USERNAME"   '. + {username: $u}')
[ -n "$AVATAR_URL" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg a "$AVATAR_URL" '. + {avatar_url: $a}')
[ "$TTS" = "1" ]     && PAYLOAD=$(echo "$PAYLOAD" | jq '. + {tts: true}')
```

### Step 3 — Send

```bash
if [ -n "$ATTACH" ]; then
  # Multipart upload (file + payload_json)
  curl -sS -X POST "$DISCORD_WEBHOOK_URL" \
    -F "payload_json=$PAYLOAD" \
    -F "file1=@$ATTACH" \
    -w '\nHTTP %{http_code}\n'
else
  HTTP=$(curl -sS -o /tmp/discord-resp.json -w '%{http_code}' \
    -X POST -H 'Content-Type: application/json' \
    --data "$PAYLOAD" "$DISCORD_WEBHOOK_URL")
  case "$HTTP" in
    204|200) echo "✅ Sent (HTTP $HTTP)" ;;
    429)     RETRY=$(jq -r '.retry_after // 1' /tmp/discord-resp.json)
             echo "❌ Rate limited — retry after ${RETRY}s"; exit 1 ;;
    *)       echo "❌ HTTP $HTTP"; cat /tmp/discord-resp.json; exit 1 ;;
  esac
fi
```

## Embed JSON shape

```json
{
  "title": "Deploy succeeded",
  "description": "Version 1.2.0 shipped",
  "color": 5763719,
  "fields": [
    { "name": "Env",     "value": "prod",    "inline": true },
    { "name": "Commit",  "value": "abc1234", "inline": true }
  ],
  "footer": { "text": "ci/deploy.yml" },
  "timestamp": "2026-05-17T10:00:00Z"
}
```

Color is decimal RGB (use `printf '%d\n' 0x57F287` for hex → dec).

## Output Contract

```
## Discord send

**Webhook host:** discord.com
**Mode:**         text | embed | attachment
**Bytes:**        <payload-size>
**Status:**       ✅ HTTP 204 | ❌ <code>
```

## Gotchas

- **2000-char limit** on `content`. Split or use embeds (4096 chars per embed `description`).
- **10 embeds max** per message. Beyond that → 400 Bad Request.
- **Webhook rate limit**: 30 messages / 60s per webhook. Honor `Retry-After`.
- **Color must be decimal**, not `#hex` string. Convert first.
- **`@everyone` blocked by default** in webhook posts unless allowed in webhook settings.
- **No DMs from webhooks**: webhooks post to one channel only — use a bot for DMs.
- **Secrets in logs**: never `set -x`. Webhook URL is sufficient to post indefinitely.

## Cross-Platform Notes

- macOS / Linux: `curl` + `jq` work identically.
- Windows PowerShell: `Invoke-RestMethod -Uri $env:DISCORD_WEBHOOK_URL -Method POST -Body $json -ContentType 'application/json'`.
