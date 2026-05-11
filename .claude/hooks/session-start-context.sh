#!/usr/bin/env bash
# SessionStart Hook: Load context on launch
# Prints useful context when a Claude Code session starts in this repo

set -euo pipefail

REPO_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "OK"

# Show branch and recent activity
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
LAST_COMMIT=$(git log -1 --format="%h %s (%cr)" 2>/dev/null || echo "no commits")
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

cat <<EOF

--- claudifying session context ---
Branch: $BRANCH
Last commit: $LAST_COMMIT
Uncommitted changes: $UNCOMMITTED file(s)
Commands: $(find "$REPO_DIR/.claude/commands" -name "*.md" -not -name "_template.md" 2>/dev/null | wc -l | tr -d ' ')
Skills: $(find "$REPO_DIR/.claude/skills" -maxdepth 1 -type d -not -name "_template" -not -name "skills" 2>/dev/null | wc -l | tr -d ' ')
---
EOF
