#!/bin/bash
# Plan Gate — PreToolUse hook for Edit/Write
# Warns if no recent .spec.md file exists before editing source code.
# Non-blocking: always exits 0. This is a reminder, not a gate.
#
# Reads target file path from CLAUDE_TOOL_INPUT_FILE environment variable.

set -euo pipefail

# -- Resolve target file from tool input ---------------------------------------

# CLAUDE_TOOL_INPUT_FILE is set by Claude Code for PreToolUse hooks
INPUT_FILE="${CLAUDE_TOOL_INPUT_FILE:-}"

if [ -z "$INPUT_FILE" ]; then
  # Try reading from stdin as fallback
  INPUT=$(cat 2>/dev/null || true)
  INPUT_FILE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")
fi

if [ -z "$INPUT_FILE" ]; then
  # No file path available -- nothing to check
  exit 0
fi

# -- Extract file metadata -----------------------------------------------------

FILENAME=$(basename "$INPUT_FILE")
EXTENSION="${FILENAME##*.}"

# -- Check if this is a source code file ---------------------------------------

SOURCE_EXTENSIONS="^(cs|ts|tsx|js|jsx|py|go|rs|php|rb|java|kt|swift|dart|vb|cbl)$"
if ! echo "$EXTENSION" | grep -qE "$SOURCE_EXTENSIONS"; then
  # Not a source code file -- skip
  exit 0
fi

# -- Skip test files -----------------------------------------------------------

if echo "$FILENAME" | grep -qiE "(Test\.|\.test\.|\.spec\.|_test\.|^test_)"; then
  exit 0
fi

if echo "$INPUT_FILE" | grep -qE "/(test|tests|__tests__)/"; then
  exit 0
fi

# -- Determine project root ----------------------------------------------------

FILE_DIR=$(dirname "$INPUT_FILE")
PROJECT_DIR=$(git -C "$FILE_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$FILE_DIR")

# -- Search for recent .spec.md files -----------------------------------------
# "Recent" = modified within the last 14 days

SPEC_FILE=$(find "$PROJECT_DIR" -name "*.spec.md" -mtime -14 -type f -print -quit 2>/dev/null || true)

if [ -n "$SPEC_FILE" ]; then
  # Active spec exists -- proceed silently
  exit 0
fi

# -- No recent spec found -- print reminder ------------------------------------

echo "PLAN GATE: No .spec.md file found (modified in last 14 days)."
echo "  Consider writing a spec before implementing."
echo ""
echo "  Create a .spec.md file with:"
echo "    - Goal description"
echo "    - 'Files to Create/Modify' section listing planned file changes"
echo "    - Acceptance criteria"
echo ""
echo "  This is a reminder, not a blocker. Edit proceeding."

# Non-blocking -- always allow the edit
exit 0
