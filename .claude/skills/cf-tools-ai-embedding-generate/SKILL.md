---
name: cf-tools-ai-embedding-generate
description: "Generate text embedding vectors via OpenAI, Voyage (Anthropic-recommended), or local sentence-transformers. Trigger: /cf-tools-ai-embedding-generate"
trigger: /cf-tools-ai-embedding-generate
version: 1.0.0
---

# /cf-tools-ai-embedding-generate

Turn text into a vector of floats suitable for similarity search, RAG, clustering, etc.

Providers:
- **openai** — `text-embedding-3-small` (1536 dim) or `-large` (3072 dim). Cheap, fast, high quality.
- **voyage** — `voyage-3` series. Anthropic officially recommends Voyage for use with Claude (no native Anthropic embeddings endpoint).
- **local** — sentence-transformers via `pipx run`. CPU-friendly. No network egress.

> Remote calls cost money (small fractions of a cent each). Skill prints estimate before issuing.

## Usage

```
/cf-tools-ai-embedding-generate "the quick brown fox"
/cf-tools-ai-embedding-generate --file passages.txt           # one passage per line, batch
/cf-tools-ai-embedding-generate --provider local "offline embed"
/cf-tools-ai-embedding-generate --provider voyage --model voyage-3-large "high-quality"
/cf-tools-ai-embedding-generate --provider openai --model text-embedding-3-large --out vecs.json
```

Arguments:
1. `text` (positional, optional) — single string to embed
2. `--file <path>` — file with one passage per line (batch mode)
3. `--provider <name>` — `openai` (default) | `voyage` | `local`
4. `--model <id>` — provider-specific default below
5. `--dim <n>` — request smaller dim (OpenAI v3 only — server-side truncation + renorm)
6. `--out <path>` — write JSON array to file (else stdout)
7. `--input-type <type>` — voyage only: `query` or `document` (affects asymmetry)
8. `--dry-run` — show plan + cost estimate, skip the call

Provider defaults:
- openai → `text-embedding-3-small` (1536 dim)
- voyage → `voyage-3` (1024 dim)
- local → `sentence-transformers/all-MiniLM-L6-v2` (384 dim)

## Credentials (env vars)

```bash
export OPENAI_API_KEY="sk-..."        # provider=openai
export VOYAGE_API_KEY="pa-..."        # provider=voyage
# provider=local needs no key (downloads model on first run)
```

## What You Must Do When Invoked

### Step 1 — Resolve input

```bash
set +x  # NEVER xtrace — would leak API keys

if [ -n "$FILE" ]; then
  mapfile -t TEXTS < "$FILE"
else
  TEXTS=("$TEXT")
fi
N=${#TEXTS[@]}
PROVIDER="${PROVIDER:-openai}"
echo "Provider: $PROVIDER | items: $N"
```

### Step 2 — Cost estimate

```bash
TOTAL_CHARS=0
for t in "${TEXTS[@]}"; do TOTAL_CHARS=$((TOTAL_CHARS + ${#t})); done
TOKENS_EST=$((TOTAL_CHARS / 4))   # crude

case "$PROVIDER" in
  openai) printf 'Est cost: ~$%.6f  (%s tokens @ $0.02/M)\n' "$(awk -v t=$TOKENS_EST 'BEGIN{print t*0.02/1e6}')" "$TOKENS_EST" ;;
  voyage) printf 'Est cost: ~$%.6f  (%s tokens @ $0.18/M for voyage-3)\n' "$(awk -v t=$TOKENS_EST 'BEGIN{print t*0.18/1e6}')" "$TOKENS_EST" ;;
  local)  echo "Est cost: \$0 (local)" ;;
esac

[ "$DRY_RUN" = "1" ] && { echo "(dry run)"; exit 0; }
```

### Step 3a — OpenAI

```bash
if [ "$PROVIDER" = "openai" ]; then
  [ -z "$OPENAI_API_KEY" ] && { echo "ERROR: export OPENAI_API_KEY"; exit 1; }
  MODEL="${MODEL:-text-embedding-3-small}"

  PAYLOAD=$(jq -n --arg model "$MODEL" --argjson input "$(printf '%s\n' "${TEXTS[@]}" | jq -R . | jq -s .)" \
    '{model:$model, input:$input}')
  [ -n "$DIM" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --argjson d "$DIM" '. + {dimensions: $d}')

  RESP=$(curl -sS https://api.openai.com/v1/embeddings \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    --data "$PAYLOAD")

  # Output: [{ "text": "...", "embedding": [...] }, ...]
  echo "$RESP" | jq --argjson texts "$(printf '%s\n' "${TEXTS[@]}" | jq -R . | jq -s .)" \
    '[.data | to_entries[] | {text: $texts[.key], embedding: .value.embedding}]'
fi
```

### Step 3b — Voyage

```bash
if [ "$PROVIDER" = "voyage" ]; then
  [ -z "$VOYAGE_API_KEY" ] && { echo "ERROR: export VOYAGE_API_KEY"; exit 1; }
  MODEL="${MODEL:-voyage-3}"

  PAYLOAD=$(jq -n --arg model "$MODEL" --argjson input "$(printf '%s\n' "${TEXTS[@]}" | jq -R . | jq -s .)" \
    '{model:$model, input:$input}')
  [ -n "$INPUT_TYPE" ] && PAYLOAD=$(echo "$PAYLOAD" | jq --arg t "$INPUT_TYPE" '. + {input_type: $t}')

  RESP=$(curl -sS https://api.voyageai.com/v1/embeddings \
    -H "Authorization: Bearer $VOYAGE_API_KEY" \
    -H "Content-Type: application/json" \
    --data "$PAYLOAD")

  echo "$RESP" | jq --argjson texts "$(printf '%s\n' "${TEXTS[@]}" | jq -R . | jq -s .)" \
    '[.data | to_entries[] | {text: $texts[.key], embedding: .value.embedding}]'
fi
```

### Step 3c — Local (sentence-transformers)

```bash
if [ "$PROVIDER" = "local" ]; then
  command -v pipx >/dev/null || { echo "ERROR: install pipx — brew install pipx"; exit 1; }
  MODEL="${MODEL:-sentence-transformers/all-MiniLM-L6-v2}"

  python3 - "$MODEL" <<'PY' "${TEXTS[@]}"
import sys, json
try:
    from sentence_transformers import SentenceTransformer
except ImportError:
    print("ERROR: sentence-transformers missing", file=sys.stderr)
    print("Install: pipx install sentence-transformers   (or)   pip install sentence-transformers", file=sys.stderr)
    sys.exit(1)

model_name = sys.argv[1]
texts = sys.argv[2:]
m = SentenceTransformer(model_name)
vecs = m.encode(texts, normalize_embeddings=True).tolist()
print(json.dumps([{"text": t, "embedding": v} for t, v in zip(texts, vecs)], indent=2))
PY
fi
```

### Step 4 — Write output

```bash
# Above blocks emit JSON to stdout. Capture and route via --out
if [ -n "$OUT" ]; then
  # rerun and pipe through tee; or capture above
  : # left as exercise — wrap whole Step 3 in $(...) and tee
fi
```

## Expected Response Shapes

### OpenAI
```json
{
  "object": "list",
  "data": [
    { "object": "embedding", "index": 0, "embedding": [0.012, -0.043, ...] }
  ],
  "model": "text-embedding-3-small",
  "usage": { "prompt_tokens": 7, "total_tokens": 7 }
}
```

### Voyage
```json
{
  "object": "list",
  "data": [
    { "object": "embedding", "index": 0, "embedding": [0.011, -0.04, ...] }
  ],
  "model": "voyage-3",
  "usage": { "total_tokens": 7 }
}
```

### Local (this skill's wrapper)
```json
[
  { "text": "the quick brown fox", "embedding": [0.029, -0.144, ...] }
]
```

## Output Contract

```
## Embedding generate

**Provider:**  openai | voyage | local
**Model:**     <id>
**Items:**     <N>
**Dim:**       <D>
**Tokens:**    <usage.total_tokens or —>
**Out:**       stdout | <path>
```

The body of stdout (or `--out` file) is a JSON array of `{text, embedding}` objects.

## Gotchas

- **No Anthropic embeddings endpoint**: Anthropic does not provide first-party embeddings. They recommend Voyage AI. This skill rejects `--provider anthropic` for that reason.
- **Vector dimension mismatch**: cross-provider vectors are NOT interchangeable. Re-embed your whole corpus when switching provider/model.
- **`--dim` only on OpenAI v3 embeddings**: server truncates + renormalizes. Don't truncate client-side — you'll lose the L2 norm.
- **Voyage `input_type`**: queries and documents are embedded with different prefixes. Use `query` at search time, `document` at index time. Mismatch → worse recall.
- **Local model first run**: downloads ~90MB for MiniLM, more for `all-mpnet-base-v2`. Cached under `~/.cache/torch/sentence_transformers/`.
- **Batching**: OpenAI accepts up to 2048 inputs per request, 8192 tokens each. Voyage 128 inputs. Local: bound by RAM.
- **Cost watch**: OpenAI `-large` is 3072-dim → 2x storage + slower cosine sim. Use `-small` unless quality testing proves the upgrade.
- **API keys never logged**: `set +x` at entry. Never echo the key.

## Cross-Platform Notes

- macOS / Linux: `pipx install sentence-transformers` is the cleanest local route. Apple Silicon uses MPS automatically once PyTorch is installed.
- Windows: WSL recommended for the local provider (torch wheels nicer there).
- Air-gapped envs: use `--provider local`. Bundle the model checkpoint in the offline cache.

## Verification at install time

- `curl --version`, `jq --version` → present.
- `pipx --version` → present (or document `brew install pipx`).
- **No real embeddings call issued at install** — cost-bearing for remote providers; local provider would trigger a model download.
