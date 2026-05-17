---
name: cf-tools-data-json-flatten
description: "Flatten nested JSON to dot-bracket keys (a.b[0]=v); reverse with --inverse. Trigger: /cf-tools-data-json-flatten"
trigger: /cf-tools-data-json-flatten
version: 1.0.0
---

# /cf-tools-data-json-flatten

Flatten a deeply nested JSON document to a flat key/value map using dot-bracket notation: `a.b.c`, `a.b.d[0]`. With `--inverse`, reconstruct the nested document from a flat map. Output is JSON by default; `--env` emits `KEY=VALUE` for shell sourcing.

## Usage

```
/cf-tools-data-json-flatten config.json
/cf-tools-data-json-flatten config.json --output flat.json
/cf-tools-data-json-flatten config.json --env > config.env
/cf-tools-data-json-flatten flat.json --inverse
/cf-tools-data-json-flatten config.json --sep _   # use _ instead of .
```

Arguments:
1. `json-path` (required)
2. `--inverse` (optional) — flat → nested
3. `--output PATH` (optional) — default stdout
4. `--env` (optional) — emit `KEY=VALUE` lines (flatten only)
5. `--sep CHAR` (optional, default `.`) — key separator
6. `--bracket-style dot|bracket` (optional, default `bracket`) — `a[0]` vs `a.0` for arrays

## Why Python stdlib first

| Tool | Convention | Inverse | Available |
|---|---|---|---|
| Python recursion | configurable | ✅ | stdlib |
| `jq --stream` | `[path, value]` pairs | ⚠️ harder | always |
| `gron` | `json.a.b = 1` (assignment style) | ✅ `gron -u` | `brew install gron` |

Python wins for configurable separator + bracket style. `gron` is excellent if installed but uses its own syntax (`json.a.b = 1`). Skill outputs canonical dot-bracket so downstream tooling is stable.

## What You Must Do When Invoked

### Step 1 — Validate

```bash
JSON="$1"
[ -f "$JSON" ] || { echo "ERROR: not found: $JSON"; exit 1; }
jq -e . "$JSON" >/dev/null 2>&1 || { echo "ERROR: invalid JSON"; exit 1; }
```

### Step 2 — Flatten (default direction)

```bash
OUTPUT=$(python3 - "$JSON" "$SEP" "$BRACKET" <<'PY'
import json, sys
path, sep, style = sys.argv[1:]
def flatten(obj, prefix=""):
    out = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            key = f"{prefix}{sep}{k}" if prefix else k
            out.update(flatten(v, key))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            key = f"{prefix}[{i}]" if style == "bracket" else (f"{prefix}{sep}{i}" if prefix else str(i))
            out.update(flatten(v, key))
    else:
        out[prefix] = obj
    return out
data = json.load(open(path))
flat = flatten(data)
print(json.dumps(flat, indent=2, ensure_ascii=False))
PY
)
```

### Step 3 — Inverse (flat → nested)

```bash
if $INVERSE; then
OUTPUT=$(python3 - "$JSON" "$SEP" <<'PY'
import json, sys, re
path, sep = sys.argv[1:]
flat = json.load(open(path))
def setkey(root, parts, value):
    cur = root
    for i, part in enumerate(parts):
        last = i == len(parts) - 1
        m = re.match(r"^(.*)\[(\d+)\]$", part)
        if m:
            key, idx = m.group(1), int(m.group(2))
            if key:
                if key not in cur or not isinstance(cur[key], list): cur[key] = []
                while len(cur[key]) <= idx: cur[key].append(None)
                if last: cur[key][idx] = value
                else:
                    if cur[key][idx] is None: cur[key][idx] = {}
                    cur = cur[key][idx]
            else:  # bare [n]
                while len(cur) <= idx: cur.append(None)
                if last: cur[idx] = value
                else:
                    if cur[idx] is None: cur[idx] = {}
                    cur = cur[idx]
        else:
            if last: cur[part] = value
            else:
                if part not in cur or not isinstance(cur[part], (dict, list)): cur[part] = {}
                cur = cur[part]
root = {}
for k, v in flat.items():
    setkey(root, k.split(sep), v)
print(json.dumps(root, indent=2, ensure_ascii=False))
PY
)
fi
```

### Step 4 — --env mode

```bash
if $ENV_MODE && ! $INVERSE; then
  OUTPUT=$(echo "$OUTPUT" | jq -r 'to_entries[] | "\(.key | gsub("[^A-Za-z0-9_]"; "_"))=\(.value | @sh)"')
fi
```

### Step 5 — Write or print

```bash
if [ -n "$OUT" ]; then printf '%s\n' "$OUTPUT" > "$OUT"; else printf '%s\n' "$OUTPUT"; fi
KEYS=$(echo "$OUTPUT" | grep -c '^.' || echo 0)
echo "✅ ${KEYS} entries"
```

## Output Contract

Flatten:
```
{
  "a.b.c": 1,
  "a.b.d[0]": 2,
  "a.b.d[1]": 3,
  "e": "x"
}
```

Inverse (above input):
```
{
  "a": { "b": { "c": 1, "d": [2, 3] } },
  "e": "x"
}
```

Report:
```
## JSON flatten

**Source:**   config.json
**Direction:** flatten | inverse
**Keys:**     <N>
**Separator:** . (or custom)
**Array style:** bracket | dot
**Output:**   flat.json (or stdout, or env-format)
```

## Gotchas

- **Keys containing `.` or `[`**: round-trip is lossy. Switch `--sep` to `/` or similar to avoid collisions.
- **Empty arrays / objects**: silently dropped during flatten (no leaf to record). Add `--keep-empty` if needed (not in v1.0).
- **`--inverse` from `--env` output**: not supported. Inverse expects a flat JSON object as input.
- **--env emits shell-quoted values** via `@sh` so spaces are safe; numeric values get single quotes too — re-cast in shell if needed.
- **Heterogeneous lists**: `[1, {"k":"v"}, 2]` flattens to `arr[0]=1`, `arr[1].k="v"`, `arr[2]=2`. Inverse restores correctly.
- **Numeric-looking string keys**: dict key `"0"` becomes `0` in output — visually indistinguishable from array index. Use `--bracket-style bracket` to keep arrays clearly marked.

## Cross-Platform Notes

- **All platforms**: Python 3 stdlib only. No external deps.
- **macOS / Linux**: optional `brew install gron` if you prefer `json.a.b = 1` assignment syntax.
