---
name: cf-tools-ai-models-list
description: "List models per provider with context window and per-token pricing. Trigger: /cf-tools-ai-models-list"
trigger: /cf-tools-ai-models-list
version: 1.0.0
---

# /cf-tools-ai-models-list

Aggregate the model catalogs of Anthropic, OpenAI, and Ollama into one comparison table. Live-query API endpoints where available; fall back to a curated static map for fields the APIs don't expose (price, context window).

> Listing endpoints are cheap (often free) but still need API keys for Anthropic/OpenAI. Ollama is local-only.

## Usage

```
/cf-tools-ai-models-list                            # all providers
/cf-tools-ai-models-list --provider anthropic
/cf-tools-ai-models-list --provider openai --json
/cf-tools-ai-models-list --provider ollama
/cf-tools-ai-models-list --filter "claude"          # substring match on name
/cf-tools-ai-models-list --refresh-prices           # rebuild static price map (manual)
```

Arguments:
1. `--provider <name>` — `anthropic` | `openai` | `ollama` (default: all available)
2. `--filter <substr>` — case-insensitive substring filter on model name
3. `--json` — emit JSON array instead of human table
4. `--no-prices` — skip the static price lookup (faster, fewer columns)
5. `--refresh-prices` — print instructions for updating the embedded price table

## Credentials

```bash
export ANTHROPIC_API_KEY="sk-ant-..."   # for /v1/models
export OPENAI_API_KEY="sk-..."          # for /v1/models
# Ollama needs no key
```

## Static price table (per 1M tokens, USD — update quarterly)

Embedded in the skill body; the API doesn't return pricing, so this is the only source.

| Model                  | Input $/M | Output $/M | Context  |
|------------------------|-----------|------------|----------|
| claude-opus-4-7        | 15.00     | 75.00      | 200000   |
| claude-sonnet-4-7      | 3.00      | 15.00      | 200000   |
| claude-haiku-4-7       | 0.80      | 4.00       | 200000   |
| gpt-4o                 | 2.50      | 10.00      | 128000   |
| gpt-4o-mini            | 0.15      | 0.60       | 128000   |
| o1                     | 15.00     | 60.00      | 200000   |
| o3-mini                | 1.10      | 4.40       | 200000   |
| text-embedding-3-small | 0.02      | —          | 8191     |
| text-embedding-3-large | 0.13      | —          | 8191     |
| ollama (any)           | 0         | 0          | model-dep|

To refresh, paste current pricing from <https://www.anthropic.com/pricing> and <https://openai.com/api/pricing/> into this table and re-symlink.

## What You Must Do When Invoked

### Step 1 — Probe providers

```bash
set +x  # NEVER xtrace — API keys would leak

PROVIDERS=()
if [ -z "$ONLY_PROVIDER" ] || [ "$ONLY_PROVIDER" = "anthropic" ]; then
  [ -n "$ANTHROPIC_API_KEY" ] && PROVIDERS+=("anthropic")
fi
if [ -z "$ONLY_PROVIDER" ] || [ "$ONLY_PROVIDER" = "openai" ]; then
  [ -n "$OPENAI_API_KEY" ] && PROVIDERS+=("openai")
fi
if [ -z "$ONLY_PROVIDER" ] || [ "$ONLY_PROVIDER" = "ollama" ]; then
  curl -sf http://localhost:11434/api/tags -o /dev/null --max-time 1 && PROVIDERS+=("ollama")
fi
echo "Providers: ${PROVIDERS[*]}"
```

### Step 2 — Fetch each catalog

```bash
TMP=$(mktemp -d)

for p in "${PROVIDERS[@]}"; do
  case "$p" in
    anthropic)
      curl -sS https://api.anthropic.com/v1/models \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
      | jq '[.data[] | {provider:"anthropic", id:.id, display_name:.display_name, type:.type, created_at:.created_at}]' \
      > "$TMP/anthropic.json"
      ;;
    openai)
      curl -sS https://api.openai.com/v1/models \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
      | jq '[.data[] | {provider:"openai", id:.id, display_name:.id, owned_by:.owned_by, created:.created}]' \
      > "$TMP/openai.json"
      ;;
    ollama)
      curl -sS http://localhost:11434/api/tags \
      | jq '[.models[] | {provider:"ollama", id:.name, size_bytes:.size, modified_at:.modified_at, family:(.details.family // null), parameter_size:(.details.parameter_size // null), quantization_level:(.details.quantization_level // null)}]' \
      > "$TMP/ollama.json"
      ;;
  esac
done
```

### Step 3 — Merge + enrich with prices

```bash
# Embedded price map as JSON
read -r -d '' PRICE_MAP <<'JSON' || true
{
  "claude-opus-4-7":        { "in":15.00, "out":75.00, "ctx":200000 },
  "claude-sonnet-4-7":      { "in": 3.00, "out":15.00, "ctx":200000 },
  "claude-haiku-4-7":       { "in": 0.80, "out": 4.00, "ctx":200000 },
  "gpt-4o":                 { "in": 2.50, "out":10.00, "ctx":128000 },
  "gpt-4o-mini":            { "in": 0.15, "out": 0.60, "ctx":128000 },
  "o1":                     { "in":15.00, "out":60.00, "ctx":200000 },
  "o3-mini":                { "in": 1.10, "out": 4.40, "ctx":200000 },
  "text-embedding-3-small": { "in": 0.02, "out": null, "ctx":  8191 },
  "text-embedding-3-large": { "in": 0.13, "out": null, "ctx":  8191 }
}
JSON

ALL=$(jq -s 'add // []' "$TMP"/*.json)

if [ "$NO_PRICES" != "1" ]; then
  ALL=$(echo "$ALL" | jq --argjson prices "$PRICE_MAP" '
    map(. + {
      input_per_million:  ($prices[.id].in  // null),
      output_per_million: ($prices[.id].out // null),
      context_window:     ($prices[.id].ctx // null)
    })')
fi

[ -n "$FILTER" ] && ALL=$(echo "$ALL" | jq --arg f "$(echo "$FILTER" | tr '[:upper:]' '[:lower:]')" \
  'map(select((.id | ascii_downcase) | contains($f)))')
```

### Step 4 — Render

```bash
if [ "$AS_JSON" = "1" ]; then
  echo "$ALL" | jq .
else
  printf '%-12s %-32s %12s %12s %10s\n' "PROVIDER" "MODEL" "INPUT $/M" "OUTPUT $/M" "CONTEXT"
  printf '%-12s %-32s %12s %12s %10s\n' "--------" "--------------------------------" "------------" "------------" "----------"
  echo "$ALL" | jq -r '.[] | [
    .provider,
    .id,
    (.input_per_million  // "—" | tostring),
    (.output_per_million // "—" | tostring),
    (.context_window     // "—" | tostring)
  ] | @tsv' \
  | awk -F'\t' '{printf "%-12s %-32s %12s %12s %10s\n", $1, $2, $3, $4, $5}'
fi

rm -rf "$TMP"
```

## Expected Response Shapes

### Anthropic `/v1/models`
```json
{
  "data": [
    { "id": "claude-opus-4-7",   "display_name": "Claude Opus 4.7",   "type": "model", "created_at": "2026-01-01T00:00:00Z" },
    { "id": "claude-sonnet-4-7", "display_name": "Claude Sonnet 4.7", "type": "model", "created_at": "2026-01-01T00:00:00Z" }
  ],
  "has_more": false
}
```

### OpenAI `/v1/models`
```json
{
  "object": "list",
  "data": [
    { "id": "gpt-4o",      "object": "model", "owned_by": "openai", "created": 1715000000 },
    { "id": "gpt-4o-mini", "object": "model", "owned_by": "openai", "created": 1715000000 }
  ]
}
```

### Ollama `/api/tags`
```json
{
  "models": [
    {
      "name": "llama3.1:8b",
      "modified_at": "2026-05-01T12:00:00Z",
      "size": 4661211648,
      "details": {
        "family": "llama",
        "parameter_size": "8B",
        "quantization_level": "Q4_K_M"
      }
    }
  ]
}
```

## Output Contract

Human mode (default):
```
PROVIDER     MODEL                              INPUT $/M    OUTPUT $/M    CONTEXT
------------ -------------------------------- ------------ ------------ ----------
anthropic    claude-opus-4-7                         15.00        75.00     200000
anthropic    claude-sonnet-4-7                        3.00        15.00     200000
openai       gpt-4o                                   2.50        10.00     128000
openai       gpt-4o-mini                              0.15         0.60     128000
ollama       llama3.1:8b                                 —            —          —
```

JSON mode (`--json`):
```json
[
  { "provider": "anthropic", "id": "claude-opus-4-7", "input_per_million": 15.0, "output_per_million": 75.0, "context_window": 200000 },
  ...
]
```

## Gotchas

- **API does not return prices**: Anthropic and OpenAI list endpoints expose `id`, `display_name`, sometimes `created_at`, but never $. The static price table is the single source — it goes stale fast.
- **OpenAI returns hundreds of model rows** including legacy `ada`, `babbage`, fine-tunes, and dated snapshots (`gpt-4o-2024-08-06`). Use `--filter gpt-4o` to keep the table readable.
- **Context window mismatch**: API doesn't expose it. Static table is authoritative — verify against the provider's docs before quoting in proposals.
- **Ollama "size" is bytes on disk** (quantized weights), not parameter count. `details.parameter_size` is the human-readable param count.
- **Anthropic `/v1/models` requires the same headers as messages API** (`x-api-key`, `anthropic-version`). Without `anthropic-version`, returns 400.
- **No price for fine-tuned / custom models**: they inherit base model pricing — `gpt-4o-mini-2024-07-18` matches `gpt-4o-mini` row. The skill does a best-effort prefix match.
- **API keys never logged**: `set +x` enforced. Listing is a `GET` — still don't curl with the key in `bash -x` mode.

## Cross-Platform Notes

- macOS / Linux: `curl` + `jq` standard.
- Ollama: must be running locally (`brew services start ollama` or `ollama serve`).
- Air-gapped: skip remote providers; `ollama` listing works offline.

## Verification at install time

- `curl --version`, `jq --version` → present.
- Endpoint URLs documented; **no real list call issued at install** to avoid touching paid keys unnecessarily.
