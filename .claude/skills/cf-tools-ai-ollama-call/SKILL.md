---
name: cf-tools-ai-ollama-call
description: "Run a local LLM via Ollama CLI or HTTP API at localhost:11434. Trigger: /cf-tools-ai-ollama-call"
trigger: /cf-tools-ai-ollama-call
version: 1.0.0
---

# /cf-tools-ai-ollama-call

Send a prompt to a local LLM served by [Ollama](https://ollama.com). Two transports:

- **CLI** (`ollama run`) — simplest, blocking, streams to stdout.
- **HTTP** (`POST http://localhost:11434/api/generate`) — scriptable, JSON in/out, optional streaming.

Local-only. **No API costs.** No network egress (unless you pulled a model that calls home, which open models don't).

## Usage

```
/cf-tools-ai-ollama-call "Write a haiku about TCP"
/cf-tools-ai-ollama-call --model llama3.1 "Explain BGP"
/cf-tools-ai-ollama-call --file prompt.txt --json
/cf-tools-ai-ollama-call --system "You are terse." --stream "Status check"
/cf-tools-ai-ollama-call --host http://gpu-box:11434 "Remote ollama"
```

Arguments:
1. `prompt` (positional, optional) — user message
2. `--file <path>` — read prompt from file
3. `--system <text>` / `--system-file <path>` — system prompt
4. `--model <name>` — default `llama3.1`. Common: `llama3.2`, `llama3.1`, `qwen2.5`, `mistral`, `phi3`, `gemma3`, `deepseek-r1`.
5. `--temperature <n>` — default model-defined
6. `--num-ctx <n>` — context window override
7. `--stream` — stream tokens to stdout (CLI streams by default; HTTP needs the flag)
8. `--json` — set `format=json` (model emits valid JSON)
9. `--http` — force HTTP transport (otherwise auto: HTTP if reachable, else CLI)
10. `--host <url>` — override Ollama host (default `http://localhost:11434`)
11. `--raw` — print full HTTP response (HTTP mode only)

## Install / Setup

```bash
# Install
brew install ollama                    # macOS
curl -fsSL https://ollama.com/install.sh | sh   # Linux

# Start daemon (macOS uses launchd via brew services; Linux uses systemd)
brew services start ollama             # macOS
ollama serve &                         # any platform, foreground

# Pull a model (one-time per model)
ollama pull llama3.1                   # 4.7GB
ollama pull qwen2.5:7b                 # 4.4GB
ollama pull phi3:mini                  # 2.2GB (smallest useful)

# Sanity check
ollama list                            # shows installed models
curl -s http://localhost:11434/api/tags | jq .
```

## What You Must Do When Invoked

### Step 1 — Discover transport

```bash
HOST="${HOST:-http://localhost:11434}"

if [ "$FORCE_HTTP" = "1" ] || curl -sf "$HOST/api/tags" -o /dev/null --max-time 1; then
  TRANSPORT="http"
elif command -v ollama >/dev/null 2>&1; then
  TRANSPORT="cli"
else
  echo "ERROR: ollama not installed and HTTP API unreachable at $HOST"
  echo "Install: brew install ollama   (or)   curl -fsSL https://ollama.com/install.sh | sh"
  echo "Then:    ollama serve &"
  echo "Then:    ollama pull llama3.1"
  exit 1
fi
echo "Transport: $TRANSPORT"
```

### Step 2 — Check model availability

```bash
MODEL="${MODEL:-llama3.1}"

if [ "$TRANSPORT" = "http" ]; then
  HAS=$(curl -s "$HOST/api/tags" | jq -r ".models[].name" | grep -c "^${MODEL}\(:.*\)\?$" || true)
else
  HAS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -c "^${MODEL}\(:.*\)\?$" || true)
fi

if [ "$HAS" -eq 0 ]; then
  echo "Model not pulled. Run: ollama pull $MODEL"
  exit 1
fi
```

### Step 3a — CLI transport

```bash
if [ "$TRANSPORT" = "cli" ]; then
  PROMPT="${PROMPT_TEXT:-$(cat "$PROMPT_FILE")}"
  # CLI doesn't have a system flag in `ollama run` directly — prepend to prompt for parity
  if [ -n "$SYSTEM_TEXT" ] || [ -n "$SYSTEM_FILE" ]; then
    SYS="${SYSTEM_TEXT:-$(cat "$SYSTEM_FILE")}"
    PROMPT=$(printf '%s\n\n%s' "$SYS" "$PROMPT")
  fi
  echo "$PROMPT" | ollama run "$MODEL"
fi
```

### Step 3b — HTTP transport

```bash
if [ "$TRANSPORT" = "http" ]; then
  PROMPT="${PROMPT_TEXT:-$(cat "$PROMPT_FILE")}"
  SYSTEM="${SYSTEM_TEXT:-$(cat "$SYSTEM_FILE" 2>/dev/null)}"

  PAYLOAD=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "$PROMPT" \
    --argjson stream "${STREAM:-false}" \
    '{model:$model, prompt:$prompt, stream:$stream}')
  [ -n "$SYSTEM" ]      && PAYLOAD=$(echo "$PAYLOAD" | jq --arg s "$SYSTEM" '. + {system: $s}')
  [ "$JSON_MODE" = "1" ] && PAYLOAD=$(echo "$PAYLOAD" | jq '. + {format: "json"}')
  [ -n "$TEMPERATURE" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --argjson t "$TEMPERATURE" '. + {options: ((.options // {}) + {temperature: $t})}')
  [ -n "$NUM_CTX" ]     && PAYLOAD=$(echo "$PAYLOAD" | jq --argjson n "$NUM_CTX"     '. + {options: ((.options // {}) + {num_ctx: $n})}')

  if [ "$STREAM" = "1" ]; then
    PAYLOAD=$(echo "$PAYLOAD" | jq '. + {stream: true}')
    curl -sS -N "$HOST/api/generate" --data "$PAYLOAD" \
    | while IFS= read -r line; do
        echo "$line" | jq -j '.response // ""' 2>/dev/null
        echo "$line" | jq -e '.done == true' >/dev/null 2>&1 && break
      done
    echo
  else
    RESP=$(curl -sS "$HOST/api/generate" --data "$PAYLOAD")
    if [ "$RAW" = "1" ]; then
      echo "$RESP" | jq .
    else
      echo "$RESP" | jq -r '.response'
    fi
  fi
fi
```

## Expected Response Shape (HTTP, non-streaming)

```json
{
  "model": "llama3.1",
  "created_at": "2026-05-17T12:00:00Z",
  "response": "The assistant reply...",
  "done": true,
  "context": [1,2,3, ...],
  "total_duration":      8234567890,
  "load_duration":         12345678,
  "prompt_eval_count":            42,
  "prompt_eval_duration":  123456789,
  "eval_count":                  128,
  "eval_duration":         234567890
}
```

Streaming HTTP returns one JSON object per line, each with partial `response` text and final object marked `done: true`.

## Output Contract

```
## Ollama call

**Transport:**     cli | http
**Host:**          <url>
**Model:**         <name>
**Prompt tokens:** <prompt_eval_count or —>
**Output tokens:** <eval_count or —>
**Total time:**    <total_duration ns or —>
**Text:**
<response>
```

## Gotchas

- **First call after pull is slow**: model loads into RAM/VRAM (~10–60s). Subsequent calls reuse the loaded weights until idle timeout.
- **Out of memory**: 7B q4 model needs ~5GB free RAM. Apple Silicon: unified memory; closing other apps helps.
- **Wrong model name**: `llama3` vs `llama3.1` vs `llama3.1:8b` — tags matter. Use `ollama list` to see exact names.
- **No GPU detected on Linux**: install CUDA/ROCm drivers, then restart `ollama serve`. macOS Apple Silicon uses Metal automatically.
- **JSON mode**: still LLM best-effort — wrap in `jq -e .` to validate before downstream use.
- **`/api/generate` vs `/api/chat`**: this skill uses `generate` (single-shot). For multi-turn, use `/api/chat` with a messages array (out of scope here).
- **CLI lacks streaming control**: `ollama run` always streams. To suppress streaming for shell capture, use HTTP transport.
- **Context overflow**: prompts longer than the model's context window get silently truncated from the start. Set `--num-ctx` if you know the budget.

## Cross-Platform Notes

- **macOS**: `brew install ollama`; service via `brew services start ollama`. Apple Silicon Metal acceleration is automatic.
- **Linux**: install script provisions a systemd unit. Check `systemctl status ollama`.
- **Windows**: native installer at <https://ollama.com/download/windows>. HTTP API still on `127.0.0.1:11434`.
- **Remote / cluster**: set `OLLAMA_HOST=0.0.0.0:11434` before starting, then call from another machine via `--host`. No auth — put behind a VPN or reverse proxy.

## Verification at install time

- `which ollama` → present at `/usr/local/bin/ollama` (verified).
- `ollama list` → reachable (model list may be empty until `ollama pull` is run).
- No real generation issued during install.
