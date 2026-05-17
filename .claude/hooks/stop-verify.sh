#!/usr/bin/env bash
# Stop Hook: Nudge Claude to verify work at the end of a turn
# Runs when Claude is about to finish — reminds it to check its work

set -euo pipefail

# Check if there are uncommitted changes
CHANGES=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
STAGED=$(git diff --staged --name-only 2>/dev/null | wc -l | tr -d ' ')

if [ "$CHANGES" -gt 0 ] || [ "$STAGED" -gt 0 ]; then
  echo "REMINDER: You have $CHANGES unstaged and $STAGED staged file(s). Before finishing:"
  echo "  - Did you verify the changes work? (run tests, check output)"
  echo "  - Did you check for regressions in related code?"
  echo "  - Are there any TODOs or incomplete sections left?"
fi

exit 0
