---
name: cf-tools-notify-slack-send
description: "Post messages to Slack via incoming webhook or bot token. Trigger: /cf-tools-notify-slack-send"
trigger: /cf-tools-notify-slack-send
version: 1.0.0
---

# /cf-tools-notify-slack-send

Send messages to Slack channels via incoming webhook (default) or bot token (when overriding channel).

## Usage

```
/cf-tools-notify-slack-send "Deploy complete to prod :rocket:"
/cf-tools-notify-slack-send --file body.md
/cf-tools-notify-slack-send --channel "#alerts" "Production CPU at 95%"
/cf-tools-notify-slack-send --blocks blocks.json
```

Arguments:
1. `message` (positional, optional) — plain text or Slack mrkdwn body
2. `--file <path>` — read body from file (supports markdown / mrkdwn)
3. `--channel <name>` — override default channel (requires bot token, not webhook)
4. `--blocks <path>` — Slack Block Kit JSON payload (overrides text)
5. `--username <name>` — display name override (webhook only)
6. `--icon-emoji <:emoji:>` — avatar override (webhook only)
7. `--thread-ts <ts>` — reply in thread (bot API only)

## Credentials (env vars only — never positional)

```bash
# Option A — webhook (simplest, channel locked to webhook config)
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T.../B.../..."

# Option B — bot token (allows --channel override, threads, reactions)
export SLACK_BOT_TOKEN="xoxb-..."
```

> Webhook URLs and bot tokens MUST come from env vars. Never accept them as CLI args (bash history leak).

## What You Must Do When Invoked

### Step 1 — Detect mode

```bash
set +x  # NEVER use set -x in this skill — leaks SLACK_BOT_TOKEN

if [ -n "$SLACK_BOT_TOKEN" ] && [ -n "$CHANNEL" ]; then
  MODE="api"
elif [ -n "$SLACK_WEBHOOK_URL" ]; then
  MODE="webhook"
else
  echo "ERROR: set SLACK_WEBHOOK_URL or SLACK_BOT_TOKEN"
  exit 1
fi
```

### Step 2 — Build payload

```bash
# Read message from --file if given, else positional
if [ -n "$FILE" ]; then
  TEXT=$(cat "$FILE")
else
  TEXT="$MESSAGE"
fi

# Block Kit overrides text
if [ -n "$BLOCKS_FILE" ]; then
  PAYLOAD=$(jq -n --argjson blocks "$(cat "$BLOCKS_FILE")" \
    '{blocks: $blocks}')
else
  PAYLOAD=$(jq -n --arg text "$TEXT" '{text: $text}')
fi

# Add optional fields
[ -n "$USERNAME" ]    && PAYLOAD=$(echo "$PAYLOAD" | jq --arg u "$USERNAME" '. + {username: $u}')
[ -n "$ICON_EMOJI" ]  && PAYLOAD=$(echo "$PAYLOAD" | jq --arg e "$ICON_EMOJI" '. + {icon_emoji: $e}')
[ -n "$CHANNEL" ] && [ "$MODE" = "api" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg c "$CHANNEL" '. + {channel: $c}')
```

### Step 3 — Send

```bash
if [ "$MODE" = "webhook" ]; then
  RESP=$(curl -sS -X POST -H 'Content-Type: application/json' \
    --data "$PAYLOAD" "$SLACK_WEBHOOK_URL")
  # Webhook returns "ok" on success, error string otherwise
  [ "$RESP" = "ok" ] && echo "✅ Sent (webhook)" || { echo "❌ $RESP"; exit 1; }
else
  RESP=$(curl -sS -X POST https://slack.com/api/chat.postMessage \
    -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
    -H 'Content-Type: application/json; charset=utf-8' \
    --data "$PAYLOAD")
  OK=$(echo "$RESP" | jq -r '.ok')
  if [ "$OK" = "true" ]; then
    TS=$(echo "$RESP" | jq -r '.ts')
    echo "✅ Sent (api) ts=$TS"
  else
    ERR=$(echo "$RESP" | jq -r '.error')
    echo "❌ $ERR"; exit 1
  fi
fi
```

## Output Contract

```
## Slack send

**Mode:**     webhook | api
**Channel:**  <#channel or webhook-default>
**Bytes:**    <payload-size>
**Status:**   ✅ ok | ❌ <error>
**ts:**       <message-timestamp>   (api mode only)
```

## Gotchas

- **`channel_not_found`** (api mode): bot must be invited (`/invite @bot`) to private channels.
- **`invalid_payload`**: Block Kit JSON must be a top-level array. Wrap loose objects.
- **Mrkdwn vs markdown**: Slack uses its own dialect — `*bold*` not `**bold**`, `<url|text>` not `[text](url)`.
- **Webhook channel override silently ignored**: webhooks are bound to their configured channel — use bot token for routing.
- **Rate limits**: ~1 msg/sec per channel (api) — back off on `429`.
- **Long messages**: Slack truncates `text` at 40k chars. Use blocks with `section` chunks for longer.
- **Secrets in logs**: never `set -x` or `echo $SLACK_BOT_TOKEN`. This skill always disables xtrace.

## Cross-Platform Notes

- macOS / Linux: `curl` + `jq` ship by default on macOS, `apt install jq` on Linux.
- Windows: PowerShell `Invoke-RestMethod` works the same way — env var via `$env:SLACK_WEBHOOK_URL`.
