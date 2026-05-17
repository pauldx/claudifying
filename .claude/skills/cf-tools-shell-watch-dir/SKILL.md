---
name: cf-tools-shell-watch-dir
description: "Re-run a command whenever files in a directory change, via fswatch. Trigger: /cf-tools-shell-watch-dir"
trigger: /cf-tools-shell-watch-dir
version: 1.0.0
---

# /cf-tools-shell-watch-dir

Watch a directory and re-run a command on every change. Useful for live testing, doc rebuilds, asset transpile loops — anything that should react to file edits without setting up a full watcher framework.

## Prerequisites

```bash
command -v fswatch >/dev/null || {
  echo "fswatch not installed."
  echo "  macOS:  brew install fswatch"
  echo "  Linux:  apt install fswatch  # or build from source"
  exit 1
}
```

Linux alternative if fswatch unavailable: `inotifywait` (from `inotify-tools` package) — flow is similar but flags differ.

## Usage

```
/cf-tools-shell-watch-dir --path src/ --cmd "npm test"
/cf-tools-shell-watch-dir --path docs/ --cmd "mkdocs build" --include "*.md"
/cf-tools-shell-watch-dir --path . --cmd "make" --debounce 500
```

Arguments:
1. `--path PATH` (required) — directory to watch (recursive by default)
2. `--cmd STRING` (required) — command to run on change
3. `--include GLOB` (optional, default all files) — only react to files matching this glob
4. `--debounce MS` (optional, default `300`) — wait this many ms after last event before running
5. `--initial` (optional flag) — run the command once at startup before watching

## What You Must Do When Invoked

### Step 1 — Validate

```bash
PATH_TO_WATCH="<from --path>"
CMD="<from --cmd>"
INCLUDE="${INCLUDE:-}"
DEBOUNCE="${DEBOUNCE:-300}"

[ -d "$PATH_TO_WATCH" ] || { echo "ERROR: not a directory: $PATH_TO_WATCH"; exit 1; }
[ -z "$CMD" ] || { :; }  # require non-empty
[ -z "$CMD" ] && { echo "ERROR: --cmd required"; exit 1; }
```

### Step 2 — Initial run (optional)

```bash
if [ "$INITIAL" = "1" ]; then
  echo "▶️  Initial run..."
  eval "$CMD"
  echo ""
fi
```

### Step 3 — Start fswatch loop with debounce

```bash
echo "👀 Watching $PATH_TO_WATCH (debounce ${DEBOUNCE}ms, include='${INCLUDE:-all}')"
echo "    Command: $CMD"
echo "    Press Ctrl+C to stop."
echo ""

FSW_ARGS=(--latency $(awk "BEGIN {print $DEBOUNCE/1000}") -r "$PATH_TO_WATCH")
[ -n "$INCLUDE" ] && FSW_ARGS+=(--include "$INCLUDE" --exclude ".*")

fswatch "${FSW_ARGS[@]}" | while read -r changed; do
  echo "🔄 $(date +%H:%M:%S) Change detected: $changed"
  eval "$CMD"
  echo "✅ Done. Watching..."
  echo ""
done
```

`--latency` is the fswatch debounce equivalent — it coalesces events that arrive within the window.

### Step 4 — Trap Ctrl+C cleanly

```bash
trap 'echo ""; echo "🛑 Watcher stopped."; exit 0' INT TERM
```

## Output Contract

Skill is long-running. On startup print the config block; on each change print a one-line marker + execute command + print exit status. Stop cleanly on Ctrl+C.

```
👀 Watching <path> (debounce 300ms, include='*.ts')
    Command: npm test
    Press Ctrl+C to stop.

🔄 14:32:11 Change detected: src/foo.ts
<command output>
✅ Done. Watching...
```

## Gotchas

- **macOS `--include` syntax is regex, not glob**: `--include "\\.md$"` not `--include "*.md"`. The skill above uses fswatch glob mode (`--include` accepts ERE on most builds). Test with your fswatch version.
- **fswatch under heavy churn**: 1000s of files saved in a burst → fswatch fires once after `--latency`. Tune debounce up for tools that touch many files (webpack writes).
- **Symlinks**: fswatch does NOT follow symlinks unless `-L` passed. Safe default.
- **Linux inotify limits**: default `fs.inotify.max_user_watches` is 8192 — too low for big monorepos. Raise to 524288: `echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p`.
- **Editor temp files trigger**: vim/emacs create `.swp` / `~` files that re-trigger the watcher. Add `--exclude '\.swp$'` or use `--include` to whitelist real files.
- **Long-running --cmd blocks next event**: if `npm test` takes 30s, all changes during that 30s are coalesced into a single re-run after — usually what you want.

## Cross-Platform Notes

- **macOS**: `brew install fswatch`. Uses FSEvents under the hood — efficient for large trees.
- **Linux**: `fswatch` available via package manager; uses inotify. Or use `inotifywait -m -r --format '%w%f' --event modify,create,delete $DIR` directly.
- **WSL**: inotify on the Linux side; cross-filesystem watches (between `/mnt/c` and Linux fs) drop events. Watch only inside the WSL FS.
