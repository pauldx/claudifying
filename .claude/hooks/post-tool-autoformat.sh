#!/usr/bin/env bash
# PostToolUse Hook: Auto-format after file writes
# Runs the project's formatter on files that Claude just edited
# Claude generates well-formatted code; this handles the last 10%

set -euo pipefail

# The tool result comes via stdin — extract the file path if it's an Edit/Write
FILE_PATH="${CLAUDE_TOOL_ARG_FILE_PATH:-}"

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Detect formatter and run it
EXT="${FILE_PATH##*.}"

case "$EXT" in
  js|jsx|ts|tsx|json|css|scss|md|yaml|yml)
    # Prettier (most common for web projects)
    if command -v npx &>/dev/null && [ -f "$(git rev-parse --show-toplevel 2>/dev/null)/node_modules/.bin/prettier" 2>/dev/null ]; then
      npx prettier --write "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  py)
    # Black or ruff for Python
    if command -v ruff &>/dev/null; then
      ruff format "$FILE_PATH" 2>/dev/null || true
    elif command -v black &>/dev/null; then
      black --quiet "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  go)
    # gofmt for Go
    if command -v gofmt &>/dev/null; then
      gofmt -w "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  rs)
    # rustfmt for Rust
    if command -v rustfmt &>/dev/null; then
      rustfmt "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
esac

exit 0
