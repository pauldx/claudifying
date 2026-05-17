---
name: cf-tools-productivity-clipboard-copy
description: "Copy stdin or file contents to the system clipboard (pbcopy on macOS, xclip/wl-copy on Linux). Trigger: /cf-tools-productivity-clipboard-copy"
trigger: /cf-tools-productivity-clipboard-copy
version: 1.0.0
---

# /cf-tools-productivity-clipboard-copy

Send text to the OS clipboard. Cross-platform wrapper around `pbcopy` (macOS), `xclip` / `xsel` (X11), and `wl-copy` (Wayland).

## Usage

```
echo "hello" | /cf-tools-productivity-clipboard-copy
/cf-tools-productivity-clipboard-copy /path/to/file.txt
/cf-tools-productivity-clipboard-copy --strip /path/to/file.txt   # trim trailing newline
```

Arguments:
1. `path` (optional) — if omitted, reads stdin
2. `--strip` (optional) — drop a single trailing newline before copying

## What You Must Do When Invoked

### Step 1 — Detect platform and clipboard tool

```bash
PLATFORM="$(uname -s)"
COPY_CMD=""

case "$PLATFORM" in
  Darwin)
    COPY_CMD="pbcopy"
    ;;
  Linux)
    if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy >/dev/null 2>&1; then
      COPY_CMD="wl-copy"
    elif command -v xclip >/dev/null 2>&1; then
      COPY_CMD="xclip -selection clipboard"
    elif command -v xsel >/dev/null 2>&1; then
      COPY_CMD="xsel --clipboard --input"
    else
      echo "ERROR: no clipboard tool found."
      echo "Install one: sudo apt install xclip   (or wl-clipboard on Wayland)"
      exit 2
    fi
    ;;
  *)
    echo "ERROR: unsupported platform: $PLATFORM"
    exit 2
    ;;
esac
```

### Step 2 — Read source

```bash
SRC="$1"
if [ -n "$SRC" ] && [ "$SRC" != "--strip" ]; then
  [ -f "$SRC" ] || { echo "ERROR: file not found: $SRC"; exit 1; }
  PAYLOAD="$(cat "$SRC")"
  SRC_LABEL="$SRC"
else
  PAYLOAD="$(cat)"
  SRC_LABEL="stdin"
fi

if [ "$STRIP" = "1" ]; then
  PAYLOAD="${PAYLOAD%$'\n'}"
fi
```

### Step 3 — Copy and report

```bash
printf '%s' "$PAYLOAD" | eval "$COPY_CMD"
BYTES=${#PAYLOAD}
LINES=$(printf '%s' "$PAYLOAD" | wc -l | tr -d ' ')
echo "✅ Copied to clipboard"
echo "   Source:   $SRC_LABEL"
echo "   Bytes:    $BYTES"
echo "   Lines:    $LINES"
echo "   Tool:     $COPY_CMD"
```

## Output Contract

```
## Clipboard copy
**Source:**   stdin | <abs-path>
**Bytes:**    <N>
**Lines:**    <N>
**Tool:**     pbcopy | xclip | xsel | wl-copy
**Preview:**  "<first 60 chars>…"
```

## Gotchas

- **macOS pbcopy strips trailing newlines silently**: that's normal; not a bug.
- **xclip vs xsel**: prefer xclip — wider install base. Both use `-selection clipboard` (not primary).
- **Wayland over X11**: if both `DISPLAY` and `WAYLAND_DISPLAY` are set, prefer `wl-copy` to match active session.
- **SSH sessions**: clipboard tools fail without a display server. Recommend `OSC52` escape sequences for remote shells (out of scope here).
- **Binary data**: this skill is text-only. Don't pipe images or raw bytes — use the OS file-clipboard for that.
- **Very large payloads**: macOS pbcopy has been observed to truncate >65k chars in some shells; warn if input exceeds 50k.

## Cross-Platform Notes

- **macOS**: `pbcopy` ships built-in. Paste with `pbpaste`.
- **Linux X11**: `sudo apt install xclip` or `sudo apt install xsel`.
- **Linux Wayland**: `sudo apt install wl-clipboard` (provides `wl-copy`/`wl-paste`).
- **Windows / WSL**: use `clip.exe` from inside WSL: `cat file | clip.exe`. Not auto-detected by this skill yet.
