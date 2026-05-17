#!/usr/bin/env bash
# Hook Template: Safe Global Modifications
# Copy this file and modify for your use case
# See README.md for safety patterns

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────

HOOK_NAME="$(basename "$0")"
TARGET_FILE="${TARGET_FILE:-$HOME/.claude/settings.json}"  # Change this
BACKUP_DIR="$HOME/.claude/backups/hooks"
HOOKS_LOG="$HOME/.claude/hooks.log"

# ─────────────────────────────────────────────────────────────
# Logging & Cleanup
# ─────────────────────────────────────────────────────────────

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$HOOK_NAME] $*" >> "$HOOKS_LOG"
}

on_error() {
  log "ERROR: Hook failed with exit code $?"
  if [ -n "${BACKUP_FILE:-}" ] && [ -f "$BACKUP_FILE" ]; then
    log "Restoring from backup: $BACKUP_FILE"
    cp "$BACKUP_FILE" "$TARGET_FILE" 2>/dev/null || true
  fi
  exit 1
}

trap on_error ERR

# ─────────────────────────────────────────────────────────────
# Safety: Create Backup
# ─────────────────────────────────────────────────────────────

BACKUP_FILE=""
if [ -f "$TARGET_FILE" ]; then
  mkdir -p "$BACKUP_DIR"
  BACKUP_FILE="$BACKUP_DIR/$(basename "$TARGET_FILE").backup-$(date +%s)"
  cp "$TARGET_FILE" "$BACKUP_FILE"
  log "Backup created: $BACKUP_FILE"
  echo "Backup: $BACKUP_FILE" >&2
fi

# ─────────────────────────────────────────────────────────────
# Safety: Confirmation Prompt (for destructive ops)
# ─────────────────────────────────────────────────────────────

# Uncomment for destructive operations:
# read -p "WARNING: This will modify global state. Continue? (y/n) " -n 1 -r <&1
# echo
# if [[ ! $REPLY =~ ^[Yy]$ ]]; then
#   log "User cancelled operation"
#   exit 0
# fi

# ─────────────────────────────────────────────────────────────
# Perform Modification
# ─────────────────────────────────────────────────────────────

# TODO: Add your modification logic here
# Example: Add a new key to settings.json, update .bashrc, etc.

log "Modification completed successfully"

# ─────────────────────────────────────────────────────────────
# Report
# ─────────────────────────────────────────────────────────────

if [ -n "$BACKUP_FILE" ]; then
  echo "Modified: $TARGET_FILE" >&2
  echo "Backup:   $BACKUP_FILE" >&2
  echo "Logs:     $HOOKS_LOG" >&2
fi

exit 0
