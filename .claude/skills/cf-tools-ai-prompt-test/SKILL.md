---
name: cf-tools-ai-prompt-test
description: "Send the same prompt to multiple LLM providers and compare outputs side-by-side. Trigger: /cf-tools-ai-prompt-test"
trigger: /cf-tools-ai-prompt-test
version: 1.0.0
---

# /cf-tools-ai-prompt-test

Send one prompt to multiple providers (Anthropic, OpenAI, Ollama) and print a side-by-side comparison with token + estimated cost summary.

> Anthropic and OpenAI calls cost money. Ollama is free (local). The skill prints a cost estimate before issuing remote calls and supports `--dry-run` to skip them.

## Usage

```
/cf-tools-ai-prompt-test "Summarize CAP theorem in 2 sentences"
/cf-tools-ai-prompt-test --providers anthropic,openai --file prompt.md
/cf-tools-ai-prompt-test --providers ollama --models llama3.1,qwen2.5,phi3
/cf-tools-ai-prompt-test --dry-run "What would this cost?"
```

Arguments:
1. `prompt` (positional, optional) — user message
2. `--file <path>` — read prompt from file
3. `--system <text>` — system prompt sent to all providers
4. `--providers <list>` — comma-separated subset of `anthropic,openai,ollama`. Default: all available (env-gated).
5. `--models <list>` — comma-separated override per-provider in order. Default: `claude-opus-4-7,gpt-4o,llama3.1`.
6. `--max-tokens <n>` — default `1024`
7. `--temperature <n>` — default `0.7` (set to `0` for deterministic comparison)
8. `--dry-run` — print plan + cost estimate, skip actual calls
9. `--out <dir>` — save raw responses to `<dir>/<provider>.json` (default: tmp)

## Credentials (env vars; provider is skipped if missing)

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
# Ollama needs no key — just `ollama serve` running locally
```

## What You Must Do When Invoked

### Step 1 — Resolve provider list

```bash
set +x  # NEVER xtrace — would leak API keys

PROMPT="${PROMPT_TEXT:-$(cat "$PROMPT_FILE")}"

PROVIDERS_REQUESTED="${PROVIDERS:-anthropic,openai,ollama}"
PROVIDERS_AVAILABLE=()
for p in ${PROVIDERS_REQUESTED//,/ }; do
  case "$p" in
    anthropic) [ -n "$ANTHROPIC_API_KEY" ] && PROVIDERS_AVAILABLE+=("anthropic") || echo "skip anthropic (no key)" ;;
    openai)    [ -n "$OPENAI_API_KEY" ]    && PROVIDERS_AVAILABLE+=("openai")    || echo "skip openai (no key)" ;;
    ollama)    curl -sf http://localhost:11434/api/tags -o /dev/null --max-time 1 \
                 && PROVIDERS_AVAILABLE+=("ollama") || echo "skip ollama (not running)" ;;
  esac
done
```

### Step 2 — Cost estimate (rough)

```bash
# Per-million-token prices — UPDATE quarterly
# Anthropic Opus 4.x: $15 in / $75 out
# OpenAI gpt-4o:      $2.50 in / $10 out
# Ollama:             $0
INPUT_TOKENS_EST=$(( $(echo -n "$PROMPT" | wc -c) / 4 ))   # crude: 4 chars/token
OUTPUT_BUDGET="${MAX_TOKENS:-1024}"

echo "## Plan"
echo "Prompt: ~$INPUT_TOKENS_EST input tokens, $OUTPUT_BUDGET output budget"
for p in "${PROVIDERS_AVAILABLE[@]}"; do
  case "$p" in
    anthropic) printf '  %-10s ~$%.4f\n' "$p" "$(awk -v i=$INPUT_TOKENS_EST -v o=$OUTPUT_BUDGET 'BEGIN{print (i*15 + o*75)/1e6}')" ;;
    openai)    printf '  %-10s ~$%.4f\n' "$p" "$(awk -v i=$INPUT_TOKENS_EST -v o=$OUTPUT_BUDGET 'BEGIN{print (i*2.5 + o*10)/1e6}')" ;;
    ollama)    printf '  %-10s $0.0000 (local)\n' "$p" ;;
  esac
done

[ "$DRY_RUN" = "1" ] && { echo "(dry run — no calls made)"; exit 0; }
```

### Step 3 — Issue calls in parallel

```bash
OUT_DIR="${OUT_DIR:-$(mktemp -d -t cf-prompt-test)}"
mkdir -p "$OUT_DIR"

# Anthropic
anthropic_call() {
  curl -sS https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    --data "$(jq -n --arg p "$PROMPT" --arg m "${ANTHROPIC_MODEL:-claude-opus-4-7}" --argjson max "${MAX_TOKENS:-1024}" \
      '{model:$m, max_tokens:$max, messages:[{role:"user", content:$p}]}')" \
    > "$OUT_DIR/anthropic.json"
}

# OpenAI
openai_call() {
  curl -sS https://api.openai.com/v1/chat/completions \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    --data "$(jq -n --arg p "$PROMPT" --arg m "${OPENAI_MODEL:-gpt-4o}" --argjson max "${MAX_TOKENS:-1024}" \
      '{model:$m, max_tokens:$max, messages:[{role:"user", content:$p}]}')" \
    > "$OUT_DIR/openai.json"
}

# Ollama
ollama_call() {
  curl -sS http://localhost:11434/api/generate \
    --data "$(jq -n --arg p "$PROMPT" --arg m "${OLLAMA_MODEL:-llama3.1}" \
      '{model:$m, prompt:$p, stream:false}')" \
    > "$OUT_DIR/ollama.json"
}

# Parallel fan-out
pids=()
for p in "${PROVIDERS_AVAILABLE[@]}"; do
  case "$p" in
    anthropic) anthropic_call & ;;
    openai)    openai_call    & ;;
    ollama)    ollama_call    & ;;
  esac
  pids+=($!)
done
for pid in "${pids[@]}"; do wait $pid; done
```

### Step 4 — Render comparison

```bash
echo
echo "## Results (saved to $OUT_DIR)"
for p in "${PROVIDERS_AVAILABLE[@]}"; do
  echo
  echo "### $p"
  case "$p" in
    anthropic)
      jq -r '"_Model: \(.model)_\n_Tokens: \(.usage.input_tokens) in / \(.usage.output_tokens) out_\n\n\(.content[0].text)"' \
        "$OUT_DIR/anthropic.json" ;;
    openai)
      jq -r '"_Model: \(.model)_\n_Tokens: \(.usage.prompt_tokens) in / \(.usage.completion_tokens) out_\n\n\(.choices[0].message.content)"' \
        "$OUT_DIR/openai.json" ;;
    ollama)
      jq -r '"_Model: \(.model)_\n_Tokens: \(.prompt_eval_count) in / \(.eval_count) out_\n_Latency: \(.total_duration / 1e9 | floor)s_\n\n\(.response)"' \
        "$OUT_DIR/ollama.json" ;;
  esac
done
```

## Expected Response Shapes

Same as the individual provider skills:

- Anthropic: `.content[0].text`, `.usage.{input_tokens,output_tokens}`
- OpenAI: `.choices[0].message.content`, `.usage.{prompt_tokens,completion_tokens,total_tokens}`
- Ollama: `.response`, `.{prompt_eval_count,eval_count,total_duration}`

## Output Contract

```
## Plan
Prompt: ~<N> input tokens, <max> output budget
  anthropic   ~$<cost>
  openai      ~$<cost>
  ollama      $0.0000 (local)

## Results (saved to <dir>)

### anthropic
_Model: claude-opus-4-7_
_Tokens: 42 in / 128 out_

<response text>

### openai
...

### ollama
...
```

## Gotchas

- **Cost surprise on long prompts**: rough estimate is `chars/4`. Real tokenizers vary ±30%. Use `--dry-run` first on big prompts.
- **Apples-to-oranges**: different models have different defaults (temp, system prompts, RLHF style). Set `--temperature 0` for the closest you can get to deterministic comparison.
- **Anthropic Opus is much more expensive than OpenAI gpt-4o** for the same output length. Pick `claude-haiku-4-7` if cost-sensitive.
- **Ollama "tokens" are model-specific** — not directly comparable across model families. Use latency + char count as secondary measures.
- **Streaming not used here**: each provider returns its full response before comparison renders. For very long outputs, this means waiting for the slowest.
- **Rate limits stack**: parallel fan-out can trip provider-side throttles if you have low-tier accounts. Run sequentially on free tier.
- **No retries**: if any provider 5xx's, that cell will be empty. Re-run only that provider rather than the whole battery.
- **API keys never logged**: `set +x` enforced at entry. Raw responses in `$OUT_DIR` may include `id` and `model` but no keys.

## Cross-Platform Notes

- macOS / Linux: `curl` + `jq` standard. Ollama requires local daemon.
- Windows PowerShell: parallel via `Start-Job`. Same JSON shapes.
- CI: provide keys via secrets; pin `--providers` to remote providers (no ollama) and use `--temperature 0` for snapshot tests.

## Verification at install time

- `curl --version`, `jq --version` → present.
- Ollama check via `curl http://localhost:11434/api/tags` (skip cleanly if 404).
- **No real provider calls issued at install** — cost-bearing.
