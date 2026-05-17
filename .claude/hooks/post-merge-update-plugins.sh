#!/bin/bash
# Post-merge hook: auto-sync marketplace plugins after pulling changes

# Only run if plugins were modified in the pull
if git diff --name-only HEAD@{1} HEAD | grep -q "^plugins/"; then
  bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/update-marketplace-plugins.sh"
fi
