# Hooks

Event-driven automation scripts executed by Claude Code on specific triggers.

## Current Hooks

All hooks are **read-only** and operate on local repo files only. None modify global `~/.claude/` state.

- **pre-commit-secret-scan.sh** — Blocks commits with exposed secrets (AWS keys, GitHub tokens, private keys, .env files)
- **post-tool-autoformat.sh** — Auto-formats edited files using project formatters (Prettier, Black, gofmt, rustfmt)
- **session-start-context.sh** — Prints branch, uncommitted changes, command/skill count on session start
- **stop-verify.sh** — Reminds to verify work before finishing (tests, regressions, TODOs)

## Safety for Global Modifications

Any future hook that modifies global state (`~/.claude/`, system config, shell profile, etc.) MUST follow this pattern:

### 1. Backup Before Modifying
```bash
#!/usr/bin/env bash
TARGET_FILE="$HOME/.claude/settings.json"
BACKUP_DIR="$HOME/.claude/backups/hooks"

# Create backup before any modification
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/$(basename "$TARGET_FILE").backup-$(date +%s)"

if [ -f "$TARGET_FILE" ]; then
  cp "$TARGET_FILE" "$BACKUP_FILE"
  echo "Backup created: $BACKUP_FILE"
fi
```

### 2. Prompt User for Confirmation
```bash
# For destructive operations, prompt user
read -p "This will modify global settings. Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled. No changes made."
  exit 0
fi
```

### 3. Log Changes
```bash
# Log what was changed
LOG_FILE="$HOME/.claude/hooks.log"
echo "[$(date)] Hook: $(basename "$0") — Modified $TARGET_FILE" >> "$LOG_FILE"
```

### 4. Error Handling
```bash
# Set strict error handling
set -euo pipefail

# If modification fails, restore backup
if ! perform_modification; then
  if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$TARGET_FILE"
    echo "Modification failed. Restored from backup: $BACKUP_FILE"
  fi
  exit 1
fi
```

## Hook Types

| Trigger | Hook Name | Example |
|---------|-----------|---------|
| Pre-commit | `pre-commit-*.sh` | pre-commit-secret-scan.sh |
| Post-tool | `post-tool-*.sh` | post-tool-autoformat.sh |
| Session start | `session-start-*.sh` | session-start-context.sh |
| Before stop | `stop-*.sh` | stop-verify.sh |

## Configuring Hooks in settings.json

Hooks are registered in Claude Code settings:

```json
{
  "hooks": {
    "pre-commit": ["~/.claude/hooks/pre-commit-secret-scan.sh"],
    "post-tool-use": ["~/.claude/hooks/post-tool-autoformat.sh"],
    "session-start": ["~/.claude/hooks/session-start-context.sh"],
    "stop": ["~/.claude/hooks/stop-verify.sh"]
  }
}
```

## Best Practices

1. **Fail safely** — If a hook fails, it should not block critical operations (unless intentional)
2. **No side effects** — Hooks should be idempotent; running twice should be safe
3. **Fast execution** — Keep hooks under 1 second to avoid slow Claude Code startup
4. **Error messages** — Print actionable error messages to stdout
5. **Logging** — Log significant actions for debugging
6. **Testing** — Test hooks manually before committing
7. **Backups** — Always backup before modifying global state
8. **Confirmation** — Prompt user before any destructive operation
9. **Documentation** — Document what each hook does and why

## Creating a New Hook

Copy `_template.sh` and follow the safety pattern above.
