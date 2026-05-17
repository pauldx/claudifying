---
name: cf-tools-shell-env-edit
description: "Open a shell rc file or .env in $EDITOR with a backup, optionally reload after save. Trigger: /cf-tools-shell-env-edit"
trigger: /cf-tools-shell-env-edit
version: 1.0.0
---

# /cf-tools-shell-env-edit

Safely edit `~/.zshrc`, `~/.bashrc`, `~/.profile`, or a project `.env` file. Always makes a timestamped backup first. Optionally re-sources the file after you save.

Avoids the classic "I broke my .zshrc and now my terminal won't open" failure mode.

## Usage

```
/cf-tools-shell-env-edit zshrc
/cf-tools-shell-env-edit bashrc --reload
/cf-tools-shell-env-edit profile
/cf-tools-shell-env-edit env                       # ./.env in cwd
/cf-tools-shell-env-edit --path ~/some/.env --reload
```

Arguments:
1. `target` (required, positional) — one of: `zshrc`, `bashrc`, `profile`, `env`, OR pass `--path PATH`
2. `--path PATH` (optional) — explicit file path (overrides positional)
3. `--reload` (optional flag) — `source` the file after edit (rc only) or echo a reload hint (.env)
4. `--editor STRING` (optional, default `$EDITOR` or `nano`) — editor command

## What You Must Do When Invoked

### Step 1 — Resolve target → path

```bash
case "${TARGET:-}" in
  zshrc)   FILE="$HOME/.zshrc" ;;
  bashrc)  FILE="$HOME/.bashrc" ;;
  profile) FILE="$HOME/.profile" ;;
  env)     FILE="./.env" ;;
  *)       FILE="${PATH_ARG:-}" ;;
esac

[ -z "$FILE" ] && { echo "ERROR: pass target (zshrc|bashrc|profile|env) or --path PATH"; exit 1; }
```

### Step 2 — Create file if missing (only for rc files)

```bash
case "$TARGET" in
  zshrc|bashrc|profile)
    if [ ! -f "$FILE" ]; then
      echo "📝 $FILE doesn't exist — creating empty file."
      touch "$FILE"
    fi
    ;;
  *)
    [ -f "$FILE" ] || { echo "ERROR: file not found: $FILE"; exit 1; }
    ;;
esac
```

### Step 3 — Timestamped backup

```bash
TS=$(date +%Y%m%d-%H%M%S)
BACKUP="${FILE}.bak.${TS}"
cp "$FILE" "$BACKUP"
echo "💾 Backup: $BACKUP"

# Keep only last 10 backups to avoid pollution
ls -1t "${FILE}.bak."* 2>/dev/null | tail -n +11 | xargs -r rm -f
```

### Step 4 — Open in editor

```bash
EDITOR_CMD="${EDITOR_ARG:-${EDITOR:-nano}}"
echo "✏️  Opening $FILE in $EDITOR_CMD..."
"$EDITOR_CMD" "$FILE"
EXIT=$?

if [ $EXIT -ne 0 ]; then
  echo "⚠️  Editor exited with status $EXIT — review changes before reloading."
fi
```

### Step 5 — Diff for confirmation

```bash
if diff -q "$BACKUP" "$FILE" >/dev/null 2>&1; then
  echo "✅ No changes made."
  rm "$BACKUP"  # don't keep no-op backups
  exit 0
else
  echo "✅ Changes detected. Diff:"
  diff "$BACKUP" "$FILE" | head -40
fi
```

### Step 6 — Reload (optional)

For rc files:
```bash
if [ "$RELOAD" = "1" ]; then
  case "$TARGET" in
    zshrc|bashrc|profile)
      echo ""
      echo "🔁 Reloading $FILE..."
      # `source` inside a sub-shell won't affect the parent. Print the manual command.
      echo "    Run this in your terminal:  source $FILE"
      ;;
    env)
      echo ""
      echo "🔁 .env reload hint:"
      echo "    For dotenv: app restarts pick up new values."
      echo "    For shell:  set -a; source $FILE; set +a"
      ;;
  esac
fi
```

The skill prints the reload command rather than running it — because Claude/skills run in subshells, `source` from a subshell can't affect the user's interactive shell.

## Output Contract

```
## Edit $FILE complete

**File:**     <abs path>
**Backup:**   <abs path of backup>
**Editor:**   <command used>
**Status:**   ✅ saved | ⚠️ no changes | ❌ editor error

### Diff
- removed line
+ added line

### Reload (run yourself)
  source <file>          # for rc files
  set -a; source .env; set +a   # for .env into current shell
```

## Gotchas

- **`source` from skill subshell doesn't affect user's terminal**: print the command, don't try to run it.
- **`$EDITOR` not set**: defaults to nano. Vim/VSCode users should `export EDITOR=vim` or pass `--editor`.
- **`.env` quoting**: dotenv parses don't all agree on quotes. Prefer `KEY=value` (no quotes) unless value has spaces.
- **Trailing newline**: editors usually add one. Some shells refuse to source files without a final newline.
- **rc file syntax error breaks future terminals**: backup gives the user `.bak.TS` to copy back. Skill keeps last 10 backups, prunes older.
- **Editing root-owned files**: `/etc/profile` needs sudo. The skill doesn't escalate — pass `--path /etc/profile` after `sudo claude` or similar.

## Cross-Platform Notes

- **macOS**: default shell is zsh since Catalina — `.zshrc` is your primary file.
- **Linux**: default shell varies; check `echo $SHELL`. Most desktop installs default to bash → `.bashrc`.
- **Windows**: no `.zshrc`/`.bashrc`. PowerShell profile path: `$PROFILE` (e.g., `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`).
- **WSL**: edit Linux-side rc files. Don't put them on `/mnt/c/...` — line endings break sourcing.
