---
name: cf-tools-browser-open-url
description: "Open a URL in the default or specified browser (Chrome/Safari/Firefox) — macOS, Linux, WSL. Trigger: /cf-tools-browser-open-url"
trigger: /cf-tools-browser-open-url
version: 1.0.0
---

# /cf-tools-browser-open-url

Open a URL in the user's actual browser (not headless). Wraps the platform `open` / `xdg-open` / `start` command. Supports targeting a specific browser via `--browser`.

This is the "show me what I just generated" companion to the other browser skills — e.g. after `md-render-preview` writes an HTML file you want to view it.

## Usage

```
/cf-tools-browser-open-url <url-or-file>
/cf-tools-browser-open-url <url-or-file> --browser chrome
/cf-tools-browser-open-url <url-or-file> --browser safari
/cf-tools-browser-open-url <url-or-file> --browser firefox
/cf-tools-browser-open-url <url-or-file> --background       # don't steal focus (macOS only)
```

Arguments:
1. `url-or-file` (required) — URL (`https://...`) or absolute file path
2. `--browser <chrome|safari|firefox|default>` (optional, default `default`)
3. `--background` (optional, macOS only) — open without foregrounding the app

## What You Must Do When Invoked

### Step 1 — Normalize input to URL

```bash
TARGET="$1"
# If looks like a local file, convert to file:// URL
if [ -e "$TARGET" ] && [ -f "$TARGET" ]; then
  ABS="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"
  TARGET="file://$ABS"
fi

# Parse flags
BROWSER="default"; BG_FLAG=""
prev=""
for a in "$@"; do
  [ "$prev" = "--browser" ] && BROWSER="$a"
  [ "$a" = "--background" ] && BG_FLAG="-g"
  prev="$a"
done
```

### Step 2 — Open per platform

```bash
PLATFORM="$(uname -s)"

open_macos() {
  case "$BROWSER" in
    chrome)  open $BG_FLAG -a "Google Chrome" "$TARGET" ;;
    safari)  open $BG_FLAG -a "Safari" "$TARGET" ;;
    firefox) open $BG_FLAG -a "Firefox" "$TARGET" ;;
    *)       open $BG_FLAG "$TARGET" ;;
  esac
}

open_linux() {
  case "$BROWSER" in
    chrome)  google-chrome "$TARGET" >/dev/null 2>&1 & ;;
    firefox) firefox       "$TARGET" >/dev/null 2>&1 & ;;
    safari)  echo "ERROR: Safari is not available on Linux"; exit 1 ;;
    *)       xdg-open "$TARGET" >/dev/null 2>&1 & ;;
  esac
}

open_wsl_or_windows() {
  case "$BROWSER" in
    chrome|safari|firefox|default)
      # cmd.exe start handles the default; explicit chrome.exe / firefox.exe also work
      cmd.exe /c start "" "$TARGET" 2>/dev/null || powershell.exe Start-Process "$TARGET"
      ;;
  esac
}

case "$PLATFORM" in
  Darwin)             open_macos ;;
  Linux)              open_linux ;;
  MINGW*|MSYS*|CYGWIN*) open_wsl_or_windows ;;
  *) echo "Unsupported platform: $PLATFORM"; exit 1 ;;
esac

echo "OK opened $TARGET in ${BROWSER}"
```

## Output Contract

```
## Open URL

**Target:**   <url-or-file>
**Browser:**  default|chrome|safari|firefox
**Platform:** Darwin|Linux|Windows
```

## Gotchas

- **No verification possible**: there is no callback that the browser actually rendered the page. Treat success as "the open command exited 0". Don't claim the page loaded.
- **Headless contexts**: in CI or over SSH without a display, `open`/`xdg-open` may silently fail or freeze. Detect with `[ -z "$DISPLAY" ] && [ "$(uname -s)" = "Linux" ]` and refuse / use `--no-open`-style flag in the caller skill.
- **`--background` is macOS-only**: silently ignored elsewhere. Don't fake it on Linux.
- **Browser not installed**: `open -a "Firefox"` returns a clear macOS error; the Linux variants will print to stderr but the script still exits 0 because of `&`. Capture and check.
- **File paths with spaces**: the script quotes `$TARGET` — pass paths normally and let the shell handle it. Don't pre-escape.
- **Don't auto-prepend `https://`**: if the user passes `localhost:3000`, that should fail loudly, not silently rewrite to `https://localhost:3000`.

## Cross-Platform Notes

- **macOS**: `open` — supports `-a <App Name>`, `-g` (background), `-n` (new instance).
- **Linux**: `xdg-open` for default; `google-chrome` / `firefox` / `chromium` for specific.
- **WSL**: `cmd.exe /c start ""` works for both URLs and Windows file paths. Convert WSL paths with `wslpath -w`.
- **No GUI**: this skill does nothing useful. The caller should detect that and skip.
