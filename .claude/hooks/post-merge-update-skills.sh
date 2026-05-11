#!/bin/bash
# Post-merge hook: auto-sync marketplace skills after pulling changes

# Only run if skills were modified in the pull
if git diff --name-only HEAD@{1} HEAD | grep -q "^skills/"; then
  bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/update-marketplace-skills.sh"
fi
