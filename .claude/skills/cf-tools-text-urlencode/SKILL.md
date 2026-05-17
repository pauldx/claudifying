---
name: cf-tools-text-urlencode
description: "URL-encode or decode strings and query parameters via Python urllib. Trigger: /cf-tools-text-urlencode"
trigger: /cf-tools-text-urlencode
version: 1.0.0
---

# /cf-tools-text-urlencode

Percent-encode or decode URL components. Handles path segments, query strings, and full URLs. Uses Python's `urllib.parse` for spec compliance.

## Usage

```
echo "hello world & friends" | /cf-tools-text-urlencode
/cf-tools-text-urlencode "hello world"
echo "hello%20world%20%26" | /cf-tools-text-urlencode --decode
/cf-tools-text-urlencode "hello world" --plus            # use + for space (form-encoding)
/cf-tools-text-urlencode "https://x.com/a?q=foo bar" --component path  # encode only path
```

Arguments:
1. `input` (required) — string or file path
2. `--decode` / `-d` (optional) — decode instead of encode
3. `--plus` (optional) — use `+` for space (application/x-www-form-urlencoded)
4. `--component MODE` (optional) — `full` (default), `path`, `query`, `fragment`
5. `--safe CHARS` (optional) — extra chars to leave unencoded

## Self-Contained Snippet

```bash
TEXT="${1:-$(cat)}"
python3 -c "
import sys
from urllib.parse import quote, unquote
text = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read().rstrip('\n')
print(quote(text, safe=''))
" "$TEXT"
# Decode:
# python3 -c "from urllib.parse import unquote; print(unquote('$TEXT'))"
```

## What You Must Do When Invoked

### Step 1 — Parse flags

```bash
DECODE=0; PLUS=0; COMP="full"; SAFE=""; ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --decode|-d) DECODE=1; shift;;
    --plus) PLUS=1; shift;;
    --component) COMP="$2"; shift 2;;
    --safe) SAFE="$2"; shift 2;;
    *) ARG="$1"; shift;;
  esac
done
```

### Step 2 — Read input

```bash
if [ -f "$ARG" ]; then
  SRC=$(cat "$ARG")
elif [ -n "$ARG" ]; then
  SRC="$ARG"
else
  SRC=$(cat)
fi
```

### Step 3 — Encode/decode via Python

```bash
python3 - "$DECODE" "$PLUS" "$COMP" "$SAFE" <<PY
import sys
from urllib.parse import quote, quote_plus, unquote, unquote_plus
decode, plus, comp, safe = sys.argv[1]=="1", sys.argv[2]=="1", sys.argv[3], sys.argv[4]
text = """$SRC"""

# Component-specific safe sets
SAFE_SETS = {
    "full":     safe + "",                     # encode everything not unreserved
    "path":     safe + "/",                    # keep path separators
    "query":    safe + "=&",                   # keep query delimiters
    "fragment": safe + "/?",
}
safe_chars = SAFE_SETS.get(comp, "")

for line in text.splitlines() or [text]:
    if decode:
        print((unquote_plus if plus else unquote)(line))
    else:
        print((quote_plus if plus else quote)(line, safe=safe_chars))
PY
```

## Output Contract

```
## URL <encode|decode>

Source:    <text-or-file>
Mode:      encode | decode
Component: full | path | query | fragment
Spaces:    %20 | +
Lines:     <N>

<encoded/decoded text>
```

## Gotchas

- **`%20` vs `+` for space**: `application/x-www-form-urlencoded` (HTML forms) uses `+`. URL path/query technically uses `%20`. Browsers tolerate both in queries; servers may not. Default to `%20` unless user passes `--plus`.
- **Double-encoding**: passing already-encoded input to encode mode produces `%2520` (encoded `%`). If the user pastes a percent-encoded URL, they probably want `--decode` first.
- **`/` in path encoding**: a path segment containing literal `/` will be split by most parsers. Use `--component path --safe ''` if you need to encode slashes too.
- **Newlines in input**: a file with `\n` between URLs: the per-line loop encodes each individually, preserving newlines as separators (not encoded).
- **Reserved chars**: per RFC 3986, unreserved = `A-Z a-z 0-9 - _ . ~`. Everything else is percent-encoded by default.
- **`unquote` is lenient**: invalid sequences like `%ZZ` pass through unchanged. Use `unquote_to_bytes` if strict validation needed.

## Cross-Platform Notes

- **Python 3** required. All `urllib.parse` functions behave identically across platforms.
- **No reliable shell-only path**: `printf '%%%02X' "'X"` works for single chars but not strings with unicode.
- **`jq -Rr @uri`**: another option if `jq` is installed: `echo "hello world" | jq -Rr @uri`. Useful in JSON pipelines.
- **`curl --data-urlencode`**: convenient when piping straight into a request body, but doesn't print to stdout.
