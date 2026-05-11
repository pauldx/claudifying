#!/bin/bash
# Post-merge hook: auto-sync marketplace agents after pulling changes

# Only run if agents were modified in the pull
if git diff --name-only HEAD@{1} HEAD | grep -q "^\.claude/agents/"; then
  bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/update-marketplace-agents.sh"
fi
