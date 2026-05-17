---
name: cf-tools-net-http-request
description: "Pretty curl wrapper — color status, time/size summary, auto JSON pretty-print via jq. Trigger: /cf-tools-net-http-request"
trigger: /cf-tools-net-http-request
version: 1.0.0
---

# /cf-tools-net-http-request

A polite `curl` wrapper for ad-hoc HTTP debugging. Prints status code (color-coded), wall time, payload size, response headers, and pretty-printed JSON body when applicable. No magic — just curl with sensible defaults.

## Usage

```
/cf-tools-net-http-request <url>
/cf-tools-net-http-request <url> -X POST -d '{"a":1}'
/cf-tools-net-http-request <url> -H "Authorization: Bearer xxx"
/cf-tools-net-http-request <url> --raw      # skip jq pretty-print
```

Arguments:
1. `url` (required) — full URL including scheme
2. Remaining args (optional) — passed through to `curl` (method, headers, body, etc.)

Special flags this skill interprets (not passed to curl):
- `--raw` — disable jq pretty-print of JSON body

## What You Must Do When Invoked

### Step 1 — Build the curl command

```bash
URL="$1"
shift

# Separate skill-specific flags from passthrough args
PRETTY=1
CURL_ARGS=()
for a in "$@"; do
  case "$a" in
    --raw) PRETTY=0 ;;
    *) CURL_ARGS+=("$a") ;;
  esac
done

if [ -z "$URL" ]; then
  echo "ERROR: URL required" >&2
  exit 1
fi
```

### Step 2 — Issue request, capture body + meta separately

```bash
TMP_BODY="$(mktemp)"
TMP_HDR="$(mktemp)"
trap 'rm -f "$TMP_BODY" "$TMP_HDR"' EXIT

# -s: silent (no progress bar)
# -D: dump response headers
# -o: body to file
# -w: write-out format for timing/status meta
META=$(curl -sS -D "$TMP_HDR" -o "$TMP_BODY" \
  -w "%{http_code}|%{time_total}|%{size_download}|%{content_type}|%{url_effective}" \
  "${CURL_ARGS[@]}" "$URL")

STATUS=$(echo "$META" | cut -d'|' -f1)
TIME=$(echo "$META"   | cut -d'|' -f2)
SIZE=$(echo "$META"   | cut -d'|' -f3)
CTYPE=$(echo "$META"  | cut -d'|' -f4)
FINAL=$(echo "$META"  | cut -d'|' -f5)
```

### Step 3 — Color status, print summary

```bash
# Color picker by status class
if   [ "$STATUS" -ge 200 ] && [ "$STATUS" -lt 300 ]; then COLOR="\033[32m" # green
elif [ "$STATUS" -ge 300 ] && [ "$STATUS" -lt 400 ]; then COLOR="\033[33m" # yellow
elif [ "$STATUS" -ge 400 ];                          then COLOR="\033[31m" # red
else COLOR="\033[37m"; fi
RESET="\033[0m"

printf "${COLOR}HTTP %s${RESET}  %ss  %s bytes  %s\n" "$STATUS" "$TIME" "$SIZE" "$CTYPE"
[ "$FINAL" != "$URL" ] && printf "  redirected → %s\n" "$FINAL"
echo "--- Headers ---"
cat "$TMP_HDR"
echo "--- Body ---"
```

### Step 4 — Pretty-print body if JSON and jq available

```bash
if [ "$PRETTY" -eq 1 ] && echo "$CTYPE" | grep -qi json && command -v jq >/dev/null 2>&1; then
  if jq . "$TMP_BODY" 2>/dev/null; then
    :
  else
    cat "$TMP_BODY"   # invalid JSON despite content-type; show raw
  fi
else
  cat "$TMP_BODY"
fi
```

## Output Contract

```
HTTP 200  0.380399s  256 bytes  application/json
--- Headers ---
HTTP/2 200
date: Sat, 17 May 2026 ...
content-type: application/json
...
--- Body ---
{
  "args": {},
  "headers": { ... },
  "origin": "x.x.x.x",
  "url": "https://httpbin.org/get"
}
```

## Gotchas

- **Body printed before headers in some terminals** — buffering is per-file, so always dump both to tmp files first (done above).
- **`-w` time_total includes DNS + connect + TLS + transfer** — not just server time. For server-side latency use `%{time_starttransfer}`.
- **HTTP/2 status line has no `OK`/`Not Found` reason phrase** — only the code. Don't try to parse it from `Status:` line.
- **`-d` with single quotes on Windows cmd** breaks; tell the user to use PowerShell or escape.
- **Self-signed certs** fail by default; document `-k` (insecure) if user explicitly wants it. Do NOT add `-k` silently.
- **Large bodies (>1 MB)** — jq will pretty-print but slow. Skill should warn if size > 1048576.

## Cross-Platform Notes

- **macOS**: `curl` ships with the OS. `jq` via `brew install jq`.
- **Linux**: `apt install curl jq` or distro equivalent.
- **httpie alternative**: if user prefers, `brew install httpie` then `http GET <url>` is a richer drop-in. This skill stays curl-only for zero-deps.
- **ANSI colors**: piping the output to a file strips colors. Detect `[ -t 1 ]` and disable color codes when not a TTY.
