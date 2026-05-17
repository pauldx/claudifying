---
name: cf-tools-data-json-merge
description: "Deep-merge two or more JSON files; later files override earlier ones. Trigger: /cf-tools-data-json-merge"
trigger: /cf-tools-data-json-merge
version: 1.0.0
---

# /cf-tools-data-json-merge

Deep-merge N JSON files into one. Later files override earlier ones at every level. Arrays are replaced by default; use `--arrays concat` to append or `--arrays unique` to dedupe.

## Usage

```
/cf-tools-data-json-merge a.json b.json
/cf-tools-data-json-merge a.json b.json c.json --output merged.json
/cf-tools-data-json-merge base.json override.json --arrays concat
/cf-tools-data-json-merge a.json b.json --arrays unique
/cf-tools-data-json-merge a.json b.json --compact
```

Arguments:
1. `json-path...` (required, 2+) — files merged left-to-right
2. `--output PATH` (optional) — default stdout
3. `--arrays MODE` (optional, default `replace`) — `replace` | `concat` | `unique`
4. `--compact` (optional) — single-line output
5. `--null-removes` (optional) — a `null` in a later file deletes the key

## Why jq first

| Tool | Deep merge | N files | Array control | Available |
|---|---|---|---|---|
| `jq -s 'reduce .[] as $x ({}; . * $x)'` | ✅ | ✅ | ❌ replace only | always (jq 1.6+) |
| Python `dict` recursion | ✅ | ✅ | ✅ all modes | stdlib |
| `yq ea '. as $i ireduce ({}; . * $i)'` | ✅ | ✅ | partial | brew |

jq's `*` operator does deep merge in one line. Python handles the array modes and `--null-removes` cleanly.

## What You Must Do When Invoked

### Step 1 — Validate

```bash
FILES=()
while [[ "$1" != "" && "$1" != --* ]]; do FILES+=("$1"); shift; done
[ ${#FILES[@]} -ge 2 ] || { echo "ERROR: need 2+ JSON files"; exit 1; }
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "ERROR: not found: $f"; exit 1; }
  jq -e . "$f" >/dev/null 2>&1 || { echo "ERROR: invalid JSON: $f"; exit 1; }
done
# parse --output, --arrays, --compact, --null-removes from remaining args
```

### Step 2 — Prefer jq (when arrays=replace, no null-removes)

```bash
if [ "$ARRAYS" = "replace" ] && ! $NULL_REMOVES; then
  if $COMPACT; then JQ_FLAGS="-c"; else JQ_FLAGS=""; fi
  OUTPUT=$(jq -s $JQ_FLAGS 'reduce .[] as $x ({}; . * $x)' "${FILES[@]}")
fi
```

### Step 3 — Python fallback (handles all modes)

```bash
OUTPUT=$(python3 - "$ARRAYS" "$NULL_REMOVES" "$COMPACT" "${FILES[@]}" <<'PY'
import json, sys
arrays, nullrm, compact = sys.argv[1], sys.argv[2] == "True", sys.argv[3] == "True"
files = sys.argv[4:]

def merge(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)
        for k, v in b.items():
            if nullrm and v is None and k in out:
                del out[k]; continue
            if k in out: out[k] = merge(out[k], v)
            else: out[k] = v
        return out
    if isinstance(a, list) and isinstance(b, list):
        if arrays == "concat": return a + b
        if arrays == "unique":
            seen = []
            for x in a + b:
                if x not in seen: seen.append(x)
            return seen
        return b  # replace
    return b

result = {}
for f in files:
    result = merge(result, json.load(open(f)))
print(json.dumps(result, indent=None if compact else 2, ensure_ascii=False))
PY
)
```

### Step 4 — Write or print

```bash
if [ -n "$OUT" ]; then printf '%s\n' "$OUTPUT" > "$OUT"; else printf '%s\n' "$OUTPUT"; fi
echo "✅ Merged ${#FILES[@]} files → $([ -n "$OUT" ] && echo "$OUT" || echo "stdout")"
```

## Output Contract

For inputs:
```
a: {"name":"App","features":{"auth":true,"db":"postgres"}}
b: {"version":"1.1","features":{"db":"mysql","cache":"redis"}}
```

Default merge:
```json
{
  "name": "App",
  "features": {
    "auth": true,
    "db": "mysql",
    "cache": "redis"
  },
  "version": "1.1"
}
```

Report:
```
## JSON merge

**Sources:**     a.json, b.json, c.json (3 files)
**Arrays:**      replace | concat | unique
**Null removes:** false | true
**Output:**      merged.json (or stdout)
**Method:**      jq | python-stdlib
```

## Gotchas

- **Array semantics**: default `replace` is jq's `*` behavior. Switch to `concat` for "merge lists" or `unique` for "set union". Decide before merging configs.
- **Type conflicts**: if `a.field` is a string and `b.field` is an object, `b` wins (overwrite). No coercion.
- **--null-removes**: only Python mode. jq's `*` keeps nulls. Use Python explicitly when you want delete semantics.
- **N-way ordering**: left-to-right, so `merge a.json b.json c.json` is `(a ⊕ b) ⊕ c`. Last file's leaves win.
- **Pretty vs compact**: pretty by default (2-space indent). Use `--compact` for diff-friendly single line.
- **Huge files**: jq slurps all files into memory (`-s`). For 100MB+ inputs, stream them through Python with `ijson` (not in stdlib — document but don't require).

## Cross-Platform Notes

- **All platforms**: jq + Python 3 cover every case.
- **macOS**: jq preinstalled on recent macOS; `brew install jq` otherwise.
- **Linux**: `apt install jq` / `dnf install jq`.
- **Windows / WSL**: WSL recommended; jq available via Chocolatey/Scoop.
