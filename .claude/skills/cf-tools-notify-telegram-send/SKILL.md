---
name: cf-tools-notify-telegram-send
description: "Send Telegram messages and photos via bot API. Trigger: /cf-tools-notify-telegram-send"
trigger: /cf-tools-notify-telegram-send
version: 1.0.0
---

# /cf-tools-notify-telegram-send

Send messages or photos to a Telegram chat via the bot API.

## Usage

```
/cf-tools-notify-telegram-send "Deploy complete"
/cf-tools-notify-telegram-send --file release-notes.md --markdown
/cf-tools-notify-telegram-send --photo screenshot.png --caption "Build output"
/cf-tools-notify-telegram-send --chat-id -1001234567890 "Cross-post"
```

Arguments:
1. `message` (positional, optional) — text body (max 4096 chars)
2. `--file <path>` — read body from file
3. `--markdown` — parse body as MarkdownV2
4. `--html` — parse body as HTML
5. `--photo <path>` — upload an image (mutually exclusive with text body unless caption)
6. `--caption <text>` — caption for `--photo` (max 1024 chars)
7. `--chat-id <id>` — override default chat id from env
8. `--silent` — send with notification suppressed (`disable_notification=true`)
9. `--reply-to <message-id>` — reply to a specific message

## Credentials (env vars only)

```bash
export TELEGRAM_BOT_TOKEN="123456789:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
export TELEGRAM_CHAT_ID="-1001234567890"   # user id, group id (negative), or channel @name
```

> Bot token grants full control of the bot — leaked tokens can spam your channel.
> Never accept as positional arg. Always env.

## Bot setup (one-time)

1. DM `@BotFather`, run `/newbot`, pick name + handle → receive `TELEGRAM_BOT_TOKEN`.
2. Add the bot to your channel/group with **post messages** privilege.
3. Get the chat id:
   - DM the bot one message, then `curl https://api.telegram.org/bot$TOKEN/getUpdates | jq '.result[].message.chat.id'`
   - Channel id: forward a channel message to `@userinfobot`.

## What You Must Do When Invoked

### Step 1 — Validate env

```bash
set +x  # NEVER xtrace — TELEGRAM_BOT_TOKEN is a full credential

if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
  echo "ERROR: export TELEGRAM_BOT_TOKEN"; exit 1
fi
CHAT="${CHAT_ID:-$TELEGRAM_CHAT_ID}"
if [ -z "$CHAT" ]; then
  echo "ERROR: export TELEGRAM_CHAT_ID or pass --chat-id"; exit 1
fi
BASE="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
```

### Step 2 — Resolve body

```bash
if [ -n "$FILE" ]; then
  TEXT=$(cat "$FILE")
else
  TEXT="$MESSAGE"
fi

PARSE_MODE=""
[ "$MARKDOWN" = "1" ] && PARSE_MODE="MarkdownV2"
[ "$HTML" = "1" ]     && PARSE_MODE="HTML"
```

### Step 3a — Send text

```bash
if [ -z "$PHOTO" ]; then
  PAYLOAD=$(jq -n \
    --arg chat_id "$CHAT" \
    --arg text "$TEXT" \
    '{chat_id: $chat_id, text: $text}')
  [ -n "$PARSE_MODE" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg p "$PARSE_MODE" '. + {parse_mode: $p}')
  [ "$SILENT" = "1" ]  && PAYLOAD=$(echo "$PAYLOAD" | jq '. + {disable_notification: true}')
  [ -n "$REPLY_TO" ]   && PAYLOAD=$(echo "$PAYLOAD" | jq --argjson r "$REPLY_TO" '. + {reply_to_message_id: $r}')

  RESP=$(curl -sS -X POST "$BASE/sendMessage" \
    -H 'Content-Type: application/json' \
    --data "$PAYLOAD")
fi
```

### Step 3b — Send photo

```bash
if [ -n "$PHOTO" ]; then
  ARGS=(-F "chat_id=$CHAT" -F "photo=@$PHOTO")
  [ -n "$CAPTION" ]    && ARGS+=(-F "caption=$CAPTION")
  [ -n "$PARSE_MODE" ] && ARGS+=(-F "parse_mode=$PARSE_MODE")
  [ "$SILENT" = "1" ]  && ARGS+=(-F "disable_notification=true")
  RESP=$(curl -sS -X POST "$BASE/sendPhoto" "${ARGS[@]}")
fi
```

### Step 4 — Parse response

```bash
OK=$(echo "$RESP" | jq -r '.ok')
if [ "$OK" = "true" ]; then
  ID=$(echo "$RESP" | jq -r '.result.message_id')
  echo "✅ Sent message_id=$ID"
else
  DESC=$(echo "$RESP" | jq -r '.description')
  CODE=$(echo "$RESP" | jq -r '.error_code')
  echo "❌ $CODE $DESC"; exit 1
fi
```

## Output Contract

```
## Telegram send

**Mode:**       text | photo
**Chat:**       <id or @handle>
**Bytes:**      <payload-size>
**Status:**     ✅ message_id=<n> | ❌ <code> <desc>
```

## Gotchas

- **MarkdownV2 strict escaping**: must escape `_ * [ ] ( ) ~ \` > # + - = | { } . !` with backslash. Plain markdown ≠ MarkdownV2.
- **4096-char limit** per message — split or use file upload (`sendDocument`, out of scope here).
- **Photo 10MB / file 50MB** for `sendPhoto` / `sendDocument` respectively.
- **Bot not added / chat_id wrong**: `Bad Request: chat not found`. For groups, the bot must be a member; for channels, an admin with post privilege.
- **Privacy mode on**: bots in groups only see commands and replies unless privacy is disabled via @BotFather.
- **Rate limit**: ~30 msg/sec total, 1 msg/sec per chat, 20 msg/min per group. `429` returns `retry_after`.
- **Channel `@username` only works if public**: private channels use numeric IDs starting with `-100`.
- **Token in logs**: never `set -x`. Anyone with the token can post or read updates.

## Cross-Platform Notes

- `curl` + `jq` ship on macOS, available everywhere via package manager.
- Windows PowerShell: `Invoke-RestMethod` with `$env:TELEGRAM_BOT_TOKEN`.
- CI: store token in secret store (GitHub Actions secret, etc.), inject as env at runtime.
