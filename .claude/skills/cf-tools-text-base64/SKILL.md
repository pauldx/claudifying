---
name: cf-tools-text-base64
description: "Base64 encode or decode strings and files, cross-platform (macOS/Linux/Windows). Trigger: /cf-tools-text-base64"
trigger: /cf-tools-text-base64
version: 1.0.0
---

# /cf-tools-text-base64

Encode/decode base64. Handles the macOS/Linux flag differences automatically. Works on strings (stdin/arg) and on files.

## Usage

```
echo "hello" | /cf-tools-text-base64                       # encode stdin
/cf-tools-text-base64 "hello"                              # encode arg
echo "aGVsbG8K" | /cf-tools-text-base64 --decode           # decode stdin
/cf-tools-text-base64 image.png --file -o image.b64        # encode file
/cf-tools-text-base64 image.b64 --decode --file -o out.png # decode file
/cf-tools-text-base64 "hello" --url                        # URL-safe variant
```

Arguments:
1. `input` (required) — string, or file path with `--file`
2. `--decode` / `-d` (optional) — decode instead of encode
3. `--file` (optional) — treat input as a file path
4. `-o PATH` / `--output` (optional) — write to file instead of stdout
5. `--url` (optional) — use URL-safe alphabet (`-_` instead of `+/`) and strip padding
6. `--no-wrap` (optional) — emit single line (no 76-char wrap)

## Self-Contained Snippet

```bash
# Cross-platform decode helper:
b64_decode() {
  if base64 --help 2>&1 | grep -q '\-d'; then
    base64 -d        # GNU / coreutils
  else
    base64 -D        # BSD / macOS
  fi
}
echo "hello" | base64                # encode (same on all platforms)
echo "aGVsbG8K" | b64_decode         # decode portably
```

## What You Must Do When Invoked

### Step 1 — Parse flags

```bash
DECODE=0; FILE=0; URL=0; NOWRAP=0; OUT=""; IN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --decode|-d) DECODE=1; shift;;
    --file) FILE=1; shift;;
    --url) URL=1; shift;;
    --no-wrap) NOWRAP=1; shift;;
    -o|--output) OUT="$2"; shift 2;;
    *) IN="$1"; shift;;
  esac
done
```

### Step 2 — Detect base64 flavor

```bash
# GNU coreutils: -d for decode, -w 0 to disable wrap
# BSD (macOS):  -D for decode, -b 0 (or just no -b) for wrap control
PLATFORM=$(uname -s)
if [ "$PLATFORM" = "Darwin" ]; then
  DECODE_FLAG="-D"
  WRAP_FLAG=""        # BSD base64 wraps at 76 by default; -i/-o handle files
else
  DECODE_FLAG="-d"
  WRAP_FLAG="-w 0"
fi
```

### Step 3 — Encode or decode using Python (safest portable path)

```bash
# Prefer Python — same behavior on macOS, Linux, Windows
python3 - "$DECODE" "$URL" "$FILE" "$NOWRAP" "$IN" "$OUT" <<'PY'
import sys, base64, pathlib
decode, url, is_file, no_wrap, src, out = sys.argv[1:7]
decode = decode == "1"; url = url == "1"; is_file = is_file == "1"; no_wrap = no_wrap == "1"

if is_file:
    data = pathlib.Path(src).read_bytes() if src else sys.stdin.buffer.read()
else:
    data = (src + "\n").encode() if src else sys.stdin.buffer.read()

if decode:
    s = data.decode().strip()
    pad = '=' * (-len(s) % 4)
    raw = base64.urlsafe_b64decode(s + pad) if url else base64.b64decode(s + pad)
    result = raw
else:
    enc = base64.urlsafe_b64encode(data) if url else base64.b64encode(data)
    if url: enc = enc.rstrip(b'=')
    if not no_wrap and not is_file:
        # Wrap at 76 chars
        enc = b'\n'.join(enc[i:i+76] for i in range(0, len(enc), 76))
    result = enc + (b'' if decode else b'\n')

if out:
    pathlib.Path(out).write_bytes(result)
else:
    sys.stdout.buffer.write(result)
PY
```

## Output Contract

```
## Base64 <encode|decode>

Source:   <stdin|file>
Output:   <stdout|file>
Variant:  standard | url-safe
Wrap:     76-col | none
Bytes in:  <N>
Bytes out: <M>
```

## Gotchas

- **`-d` vs `-D` vs `--decode`**: GNU coreutils uses lowercase `-d`. BSD (macOS) uses uppercase `-D`. Both accept the long form `--decode` — that's the safest flag if you must shell out, but actually macOS's `base64` does **not** accept `--decode` in older versions. Use Python for portability.
- **macOS `base64 -i file -o out`**: BSD base64 supports `-i input` and `-o output`. GNU base64 does **not** — it expects a positional file argument. Don't mix flag styles across platforms.
- **Padding**: standard base64 must be a multiple of 4. URL-safe base64 often strips `=` padding. The Python branch re-adds it before decode.
- **Line wrapping**: BSD wraps at 76 chars by default with newlines. GNU also defaults to wrap; disable with `-w 0`. Some APIs reject wrapped base64 — use `--no-wrap`.
- **Binary safety**: always use `sys.stdin.buffer` / `sys.stdout.buffer` in Python — `sys.stdin` mangles bytes on Windows.
- **`echo` adds newline**: `echo "hello" | base64` encodes `hello\n` (6 bytes), not `hello` (5). Use `printf "%s" "hello" | base64` for exact.

## Cross-Platform Notes

| Platform | Encode | Decode | Notes |
|----------|--------|--------|-------|
| macOS (BSD) | `base64` | `base64 -D` | `-i/-o` for files |
| Linux (GNU) | `base64` | `base64 -d` | `-w 0` to disable wrap |
| Windows (Git Bash) | `base64` (coreutils) | `base64 -d` | Same as GNU |
| Python 3 | `base64.b64encode` | `base64.b64decode` | Identical everywhere |
| OpenSSL | `openssl base64` | `openssl base64 -d` | Available where openssl ships |
