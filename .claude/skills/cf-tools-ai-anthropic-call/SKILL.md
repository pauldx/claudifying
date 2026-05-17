---
name: cf-tools-ai-anthropic-call
description: "One-shot prompt to Claude via Anthropic API. Trigger: /cf-tools-ai-anthropic-call"
trigger: /cf-tools-ai-anthropic-call
version: 1.0.0
---

# /cf-tools-ai-anthropic-call

Send a single prompt to Claude via the Anthropic Messages API and print the assistant's text response. Optimized for shell scripting (text-only output by default) with optional streaming.

> This skill **costs money per call**. The implementer (you) must NOT make test calls during dev. Verify only that `curl` is present and that the `ANTHROPIC_API_KEY` env is set before suggesting a real run.

## Usage

```
/cf-tools-ai-anthropic-call "Summarize CHANGELOG.md in 3 bullets"
/cf-tools-ai-anthropic-call --file prompt.txt
/cf-tools-ai-anthropic-call --system "You are a terse senior eng." "Review this diff"
/cf-tools-ai-anthropic-call --model claude-sonnet-4-7 --stream "Write a haiku"
/cf-tools-ai-anthropic-call --json "Return JSON with keys title,bullets[3]"
```

Arguments:
1. `prompt` (positional, optional) — user message
2. `--file <path>` — read prompt from file (overrides positional)
3. `--system <text>` — system prompt (style/role instructions)
4. `--system-file <path>` — system prompt from file
5. `--model <id>` — default `claude-opus-4-7`. Other valid: `claude-sonnet-4-7`, `claude-haiku-4-7`.
6. `--max-tokens <n>` — default `4096`
7. `--temperature <0..1>` — default `1.0`
8. `--stream` — stream response tokens to stdout as they arrive
9. `--json` — instruct model to return JSON; print only the JSON object
10. `--raw` — print the full API response JSON instead of just the text

## Credentials

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

Optional:
```bash
export ANTHROPIC_BASE_URL="https://api.anthropic.com"   # override for proxies
```

> Never accept the API key as a positional arg. Bash history leak risk.

## What You Must Do When Invoked

### Step 1 — Validate env

```bash
set +x  # NEVER xtrace — ANTHROPIC_API_KEY would leak

if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "ERROR: export ANTHROPIC_API_KEY=sk-ant-..."; exit 1
fi
command -v curl >/dev/null || { echo "ERROR: curl missing"; exit 1; }
command -v jq   >/dev/null || { echo "ERROR: jq missing — brew install jq"; exit 1; }
```

### Step 2 — Build request

```bash
PROMPT="${PROMPT_TEXT:-$(cat "$PROMPT_FILE")}"
SYSTEM="${SYSTEM_TEXT:-$(cat "$SYSTEM_FILE" 2>/dev/null)}"

PAYLOAD=$(jq -n \
  --arg model "${MODEL:-claude-opus-4-7}" \
  --argjson max_tokens "${MAX_TOKENS:-4096}" \
  --argjson temperature "${TEMPERATURE:-1.0}" \
  --arg prompt "$PROMPT" \
  '{
    model: $model,
    max_tokens: $max_tokens,
    temperature: $temperature,
    messages: [{role: "user", content: $prompt}]
  }')

[ -n "$SYSTEM" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg s "$SYSTEM" '. + {system: $s}')
[ "$STREAM" = "1" ] && PAYLOAD=$(echo "$PAYLOAD" | jq '. + {stream: true}')
```

### Step 3 — Call API

Non-streaming:
```bash
RESP=$(curl -sS https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  --data "$PAYLOAD")

if [ "$RAW" = "1" ]; then
  echo "$RESP" | jq .
else
  echo "$RESP" | jq -r '.content[0].text'
fi
```

Streaming (SSE):
```bash
curl -sS -N https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  --data "$PAYLOAD" \
| while IFS= read -r line; do
    case "$line" in
      data:*) chunk=${line#data: }
              echo "$chunk" | jq -r 'select(.type=="content_block_delta") | .delta.text' 2>/dev/null
              ;;
    esac
  done
echo  # trailing newline
```

## Expected Response Shape (non-streaming)

```json
{
  "id": "msg_01...",
  "type": "message",
  "role": "assistant",
  "model": "claude-opus-4-7",
  "content": [
    { "type": "text", "text": "The assistant reply..." }
  ],
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 42,
    "output_tokens": 128
  }
}
```

Streaming SSE event types: `message_start`, `content_block_start`, `content_block_delta`, `content_block_stop`, `message_delta`, `message_stop`. The skill consumes only `content_block_delta` for text.

## Output Contract

```
## Anthropic call

**Model:**         claude-opus-4-7
**Input tokens:**  <n>
**Output tokens:** <n>
**Stop reason:**   end_turn | max_tokens | stop_sequence
**Text:**
<response>
```

When `--json` is used, the model is prompted to emit only valid JSON; the skill parses and re-prints it pretty.

## Gotchas

- **Cost-bearing**: every call charges your account. Use Haiku for cheap iteration; Opus for reasoning-heavy tasks.
- **`anthropic-version` header required** — without it, the API returns 400.
- **`max_tokens` is the cap on output, not total**. Total request size is bounded by the model's context window (200k tokens for Claude 4.x).
- **Streaming requires `--stream` AND `Accept: text/event-stream`** (curl `-N` keeps the connection open).
- **JSON mode is best-effort**: append `Respond with only valid JSON, no prose.` to the system prompt and validate with `jq` before downstream use.
- **Rate limits**: free tier ≈ 5 RPM, paid tier ≈ 50–4000 RPM depending on org. `429` returns `retry-after` header.
- **Don't log the API key**: never `set -x`, never `echo $ANTHROPIC_API_KEY`, never include the key in error messages.
- **Long prompts**: prefer `--file` over inline — bash arg limits truncate around 128KB.

## Cross-Platform Notes

- macOS / Linux: `curl` + `jq` work identically. SDK install (optional, not used by this skill): `pipx install anthropic`.
- Python SDK equivalent (for reference only — this skill uses curl to stay dependency-free):
  ```python
  from anthropic import Anthropic
  client = Anthropic()  # reads ANTHROPIC_API_KEY from env
  m = client.messages.create(model="claude-opus-4-7", max_tokens=1024,
                             messages=[{"role":"user","content":"hi"}])
  print(m.content[0].text)
  ```
- Windows PowerShell: `Invoke-RestMethod` with `-Headers @{ "x-api-key" = $env:ANTHROPIC_API_KEY }`.

## Verification at install time

- `curl --version` → OK
- `jq --version` → OK
- `[ -n "$ANTHROPIC_API_KEY" ]` → checked, not used (no real API call made during install).
