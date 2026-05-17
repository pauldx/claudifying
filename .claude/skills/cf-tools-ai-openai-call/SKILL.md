---
name: cf-tools-ai-openai-call
description: "One-shot prompt to OpenAI Chat Completions API. Trigger: /cf-tools-ai-openai-call"
trigger: /cf-tools-ai-openai-call
version: 1.0.0
---

# /cf-tools-ai-openai-call

Send a single prompt to OpenAI via the Chat Completions API and print the assistant's text response. Optional streaming via SSE.

> Cost-bearing. Implementer must NOT make real API calls during install. Verify only CLI presence + env var set.

## Usage

```
/cf-tools-ai-openai-call "Translate to French: hello world"
/cf-tools-ai-openai-call --file prompt.txt
/cf-tools-ai-openai-call --system "You are concise." --stream "Explain ZK proofs"
/cf-tools-ai-openai-call --model gpt-4o-mini "Cheap call"
/cf-tools-ai-openai-call --json "Return JSON: {title, tags[3]}"
```

Arguments:
1. `prompt` (positional, optional) — user message
2. `--file <path>` — read prompt from file
3. `--system <text>` / `--system-file <path>` — system prompt
4. `--model <id>` — default `gpt-4o`. Cheap: `gpt-4o-mini`. Reasoning: `o1`, `o3-mini`.
5. `--max-tokens <n>` — default `4096` (note: for `o1`/`o3` use `max_completion_tokens`)
6. `--temperature <0..2>` — default `1.0` (ignored by `o1`/`o3`)
7. `--stream` — SSE token streaming to stdout
8. `--json` — set `response_format={"type":"json_object"}` and print only JSON
9. `--raw` — print full API response JSON

## Credentials

```bash
export OPENAI_API_KEY="sk-..."
```

Optional:
```bash
export OPENAI_BASE_URL="https://api.openai.com/v1"   # or proxy
export OPENAI_ORG="org_..."                           # multi-org accounts
```

> Never accept the API key as a positional arg.

## What You Must Do When Invoked

### Step 1 — Validate env

```bash
set +x  # NEVER xtrace — OPENAI_API_KEY would leak

if [ -z "$OPENAI_API_KEY" ]; then
  echo "ERROR: export OPENAI_API_KEY=sk-..."; exit 1
fi
command -v curl >/dev/null || { echo "ERROR: curl missing"; exit 1; }
command -v jq   >/dev/null || { echo "ERROR: jq missing"; exit 1; }
```

### Step 2 — Build request

```bash
PROMPT="${PROMPT_TEXT:-$(cat "$PROMPT_FILE")}"
MODEL="${MODEL:-gpt-4o}"

MSGS=$(jq -n --arg p "$PROMPT" '[{role:"user", content:$p}]')
if [ -n "$SYSTEM_TEXT" ] || [ -n "$SYSTEM_FILE" ]; then
  SYS="${SYSTEM_TEXT:-$(cat "$SYSTEM_FILE")}"
  MSGS=$(echo "$MSGS" | jq --arg s "$SYS" '[{role:"system",content:$s}] + .')
fi

# o1/o3 reasoning models use max_completion_tokens
if [[ "$MODEL" == o1* || "$MODEL" == o3* ]]; then
  PAYLOAD=$(jq -n \
    --arg model "$MODEL" \
    --argjson msgs "$MSGS" \
    --argjson max "${MAX_TOKENS:-4096}" \
    '{model:$model, messages:$msgs, max_completion_tokens:$max}')
else
  PAYLOAD=$(jq -n \
    --arg model "$MODEL" \
    --argjson msgs "$MSGS" \
    --argjson max "${MAX_TOKENS:-4096}" \
    --argjson temp "${TEMPERATURE:-1.0}" \
    '{model:$model, messages:$msgs, max_tokens:$max, temperature:$temp}')
fi

[ "$STREAM" = "1" ] && PAYLOAD=$(echo "$PAYLOAD" | jq '. + {stream: true}')
[ "$JSON_MODE" = "1" ] && PAYLOAD=$(echo "$PAYLOAD" | jq '. + {response_format: {type:"json_object"}}')
```

### Step 3 — Call API

Non-streaming:
```bash
URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}/chat/completions"
HDRS=(-H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json")
[ -n "$OPENAI_ORG" ] && HDRS+=(-H "OpenAI-Organization: $OPENAI_ORG")

RESP=$(curl -sS "$URL" "${HDRS[@]}" --data "$PAYLOAD")
if [ "$RAW" = "1" ]; then
  echo "$RESP" | jq .
else
  echo "$RESP" | jq -r '.choices[0].message.content'
fi
```

Streaming:
```bash
curl -sS -N "$URL" "${HDRS[@]}" --data "$PAYLOAD" \
| while IFS= read -r line; do
    [ "$line" = "data: [DONE]" ] && break
    case "$line" in
      data:*) chunk=${line#data: }
              echo "$chunk" | jq -j '.choices[0].delta.content // ""' 2>/dev/null
              ;;
    esac
  done
echo
```

## Expected Response Shape (non-streaming)

```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "model": "gpt-4o-2024-08-06",
  "choices": [{
    "index": 0,
    "message": { "role": "assistant", "content": "..." },
    "finish_reason": "stop"
  }],
  "usage": {
    "prompt_tokens": 42,
    "completion_tokens": 128,
    "total_tokens": 170
  }
}
```

Streaming SSE chunks have `choices[0].delta.content` (partial string). Terminated by `data: [DONE]`.

## Output Contract

```
## OpenAI call

**Model:**          <id>
**Prompt tokens:**  <n>
**Completion:**     <n>
**Total:**          <n>
**Finish:**         stop | length | content_filter | tool_calls
**Text:**
<response>
```

## Gotchas

- **Reasoning models (`o1`, `o3`, `o3-mini`)**: do NOT accept `temperature`, `top_p`, or `max_tokens`. Use `max_completion_tokens`. They internally "think" for many tokens before answering — slow + expensive.
- **JSON mode requires the word "JSON" in the prompt/system message** or OpenAI returns 400.
- **`response_format: json_object`** is not the same as structured outputs (`json_schema`) — the latter requires `gpt-4o-2024-08-06+` and a schema definition.
- **Per-org rate limits**: tier-1 ≈ 500 RPM. Headers `x-ratelimit-remaining-requests` and `retry-after` on 429.
- **Streaming + JSON mode**: combine fine, but JSON validity is only guaranteed at the end. Buffer before parsing.
- **Don't log the API key**: never `set -x`, never echo the bearer token.
- **`o1` ignores system prompts** — fold instructions into the user message.
- **Vision input requires the messages array format with image_url content blocks** — out of scope here.

## Cross-Platform Notes

- macOS / Linux: `curl` + `jq` standard. Python SDK (reference): `pipx install openai`.
- Python SDK example (not used by this skill):
  ```python
  from openai import OpenAI
  client = OpenAI()  # reads OPENAI_API_KEY
  r = client.chat.completions.create(
      model="gpt-4o",
      messages=[{"role":"user","content":"hi"}])
  print(r.choices[0].message.content)
  ```
- Windows PowerShell: `Invoke-RestMethod -Headers @{ Authorization = "Bearer $env:OPENAI_API_KEY" }`.

## Verification at install time

- `curl --version` → OK
- `jq --version` → OK
- API key presence checked but **no real call issued**.
