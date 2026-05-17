---
name: cf-tools-notify-macos-notify
description: "Show native macOS notification banner via osascript or terminal-notifier. Trigger: /cf-tools-notify-macos-notify"
trigger: /cf-tools-notify-macos-notify
version: 1.0.0
---

# /cf-tools-notify-macos-notify

Display a native macOS notification banner from the shell. Defaults to `osascript` (no install). Falls back to `terminal-notifier` when richer features (custom sound, group, click action, app icon) are requested.

## Usage

```
/cf-tools-notify-macos-notify "Build complete"
/cf-tools-notify-macos-notify --title "CI" --subtitle "main" "All green"
/cf-tools-notify-macos-notify --title "Alert" --sound Glass "Disk 90% full"
/cf-tools-notify-macos-notify --title "Done" --open https://github.com "Click to view"
```

Arguments:
1. `message` (positional, required) — notification body
2. `--title <text>` — banner title (default `Claude Code`)
3. `--subtitle <text>` — banner subtitle (line between title and body)
4. `--sound <name>` — system sound (Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink). Default: silent.
5. `--open <url|app>` — clicking notification opens URL/app (requires terminal-notifier)
6. `--group <id>` — coalesce repeat notifications (requires terminal-notifier)

## What You Must Do When Invoked

### Step 1 — Platform check

```bash
if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: macOS only. Use notify-send on Linux or BurntToast on Windows."
  exit 1
fi
```

### Step 2 — Pick backend

```bash
NEEDS_TN=0
[ -n "$OPEN_URL" ] && NEEDS_TN=1
[ -n "$GROUP_ID" ] && NEEDS_TN=1

if [ "$NEEDS_TN" = "1" ]; then
  if ! command -v terminal-notifier >/dev/null 2>&1; then
    echo "ERROR: --open and --group require terminal-notifier"
    echo "Install: brew install terminal-notifier"
    exit 1
  fi
  BACKEND="terminal-notifier"
elif command -v terminal-notifier >/dev/null 2>&1; then
  BACKEND="terminal-notifier"
else
  BACKEND="osascript"
fi
```

### Step 3a — osascript path

```bash
if [ "$BACKEND" = "osascript" ]; then
  # AppleScript needs double-quotes inside string — escape any in input
  esc() { printf '%s' "$1" | sed 's/"/\\"/g'; }

  MSG_E=$(esc "$MESSAGE")
  TITLE_E=$(esc "${TITLE:-Claude Code}")

  SCRIPT="display notification \"$MSG_E\" with title \"$TITLE_E\""
  [ -n "$SUBTITLE" ] && SCRIPT="$SCRIPT subtitle \"$(esc "$SUBTITLE")\""
  [ -n "$SOUND" ]    && SCRIPT="$SCRIPT sound name \"$(esc "$SOUND")\""

  osascript -e "$SCRIPT"
  echo "✅ Sent (osascript)"
fi
```

### Step 3b — terminal-notifier path

```bash
if [ "$BACKEND" = "terminal-notifier" ]; then
  ARGS=(-message "$MESSAGE" -title "${TITLE:-Claude Code}")
  [ -n "$SUBTITLE" ]  && ARGS+=(-subtitle "$SUBTITLE")
  [ -n "$SOUND" ]     && ARGS+=(-sound "$SOUND")
  [ -n "$OPEN_URL" ]  && ARGS+=(-open "$OPEN_URL")
  [ -n "$GROUP_ID" ]  && ARGS+=(-group "$GROUP_ID")

  terminal-notifier "${ARGS[@]}"
  echo "✅ Sent (terminal-notifier)"
fi
```

## Verification (live-tested)

This skill was verified at install time with:

```bash
osascript -e 'display notification "test" with title "cf"'   # banner appears
```

Banner appears in macOS Notification Center if "Script Editor" (osascript host) is permitted under
**System Settings → Notifications**. If silent: grant Notification permission to the calling terminal app
(Terminal.app, iTerm, Ghostty, etc.) once.

## Output Contract

```
## macOS notify

**Backend:**  osascript | terminal-notifier
**Title:**    <title>
**Subtitle:** <subtitle or —>
**Sound:**    <sound or silent>
**Status:**   ✅ delivered
```

## Gotchas

- **Silent first-run**: macOS suppresses notifications until the host app is granted permission in System Settings → Notifications. Open that pane once and enable the terminal app.
- **`Application "System Events" is not allowed assistive access`**: not actually needed — `display notification` is not in System Events. If you see this, you mistakenly called `tell application "System Events"`.
- **Double-quotes in body**: AppleScript breaks on unescaped `"`. The skill escapes via `sed`.
- **Sound name unknown**: silent. List valid names with `ls /System/Library/Sounds | sed 's/.aiff//'`.
- **Banner vs alert style**: chosen per app in System Settings, not via API.
- **Click-to-open requires terminal-notifier** — `osascript display notification` ignores click actions.
- **CI environments (no GUI)**: no banner appears — use Slack/Discord skill instead.

## Cross-Platform Notes

- **Linux**: substitute `notify-send "title" "body"` (libnotify). Not implemented here — file a separate skill.
- **Windows**: PowerShell `New-BurntToastNotification` from BurntToast module. Out of scope.
- **SSH session**: notifications fire on the *remote* machine's GUI session, not your local Mac. Use a remote-to-local bridge (e.g., Slack) instead.
