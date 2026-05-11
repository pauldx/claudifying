#!/bin/bash
# TDD Gate — PreToolUse hook for Edit/Write
# Blocks production code edits unless a corresponding test file exists.
# Exit 0 = allow, Exit 2 = block (no test found), Exit 1 = script error
#
# Reads tool input JSON from stdin with shape:
#   { "tool_name": "Edit", "tool_input": { "file_path": "/abs/path/to/file.ts", ... } }

set -euo pipefail

# -- Parse input ---------------------------------------------------------------

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  # No file path in input -- nothing to check
  exit 0
fi

# -- Extract file metadata -----------------------------------------------------

FILENAME=$(basename "$FILE_PATH")
DIRNAME=$(dirname "$FILE_PATH")
EXTENSION="${FILENAME##*.}"
NAME_NO_EXT="${FILENAME%.*}"

# -- Check if this is a production code file -----------------------------------

PROD_EXTENSIONS="^(cs|py|ts|tsx|js|jsx|go|rs|rb|php|java|kt|swift|dart)$"
if ! echo "$EXTENSION" | grep -qE "$PROD_EXTENSIONS"; then
  # Not a production code file -- skip
  exit 0
fi

# -- Skip test files -----------------------------------------------------------

# Files named with test patterns
if echo "$FILENAME" | grep -qiE "(Test\.|\.test\.|\.spec\.|_test\.|^test_)"; then
  exit 0
fi

# Files in test directories
if echo "$FILE_PATH" | grep -qE "/(test|tests|__tests__)/"; then
  exit 0
fi

# -- Skip config, migrations, DTOs, infrastructure ----------------------------

# Config files that happen to have a prod extension (rare but possible)
if echo "$FILENAME" | grep -qiE "\.(config|rc)\.(ts|js)$"; then
  exit 0
fi

# Migrations
if echo "$FILE_PATH" | grep -qiE "/(migrations?|migrate)/"; then
  exit 0
fi

# DTOs, models, entities -- thin data classes rarely need unit tests
if echo "$FILENAME" | grep -qiE "\.(dto|model|entity)\."; then
  exit 0
fi

# Infrastructure files
if echo "$FILENAME" | grep -qiE "^(Dockerfile|Makefile|docker-compose)" || echo "$EXTENSION" | grep -qE "^(tf|hcl)$"; then
  exit 0
fi

# -- Determine project root ----------------------------------------------------

PROJECT_ROOT=$(git -C "$DIRNAME" rev-parse --show-toplevel 2>/dev/null || echo "$DIRNAME")

# -- Build test file search patterns -------------------------------------------
# Common conventions: foo.test.ts, foo.spec.ts, fooTest.ts, foo_test.ts, test_foo.ts

# Strip compound extensions for pattern building (e.g., foo.service.ts -> foo.service)
BASE_NAME="$NAME_NO_EXT"

# Patterns to search for (case-sensitive to match real conventions)
SEARCH_PATTERNS=(
  "${BASE_NAME}.test.${EXTENSION}"
  "${BASE_NAME}.spec.${EXTENSION}"
  "${BASE_NAME}Test.${EXTENSION}"
  "${BASE_NAME}Spec.${EXTENSION}"
  "${BASE_NAME}_test.${EXTENSION}"
  "test_${BASE_NAME}.${EXTENSION}"
  "${BASE_NAME}.test.ts"
  "${BASE_NAME}.test.tsx"
  "${BASE_NAME}.test.js"
  "${BASE_NAME}.test.jsx"
  "${BASE_NAME}.spec.ts"
  "${BASE_NAME}.spec.tsx"
  "${BASE_NAME}.spec.js"
  "${BASE_NAME}.spec.jsx"
  "${BASE_NAME}_test.go"
  "${BASE_NAME}_test.py"
  "test_${BASE_NAME}.py"
)

# -- Search strategy 1: Same directory ----------------------------------------

for pattern in "${SEARCH_PATTERNS[@]}"; do
  if [ -f "${DIRNAME}/${pattern}" ]; then
    exit 0
  fi
done

# -- Search strategy 2: Nearby test directories --------------------------------

for test_dir in "test" "tests" "__tests__"; do
  NEARBY="${DIRNAME}/${test_dir}"
  if [ -d "$NEARBY" ]; then
    for pattern in "${SEARCH_PATTERNS[@]}"; do
      if [ -f "${NEARBY}/${pattern}" ]; then
        exit 0
      fi
    done
  fi

  # One level up
  PARENT_NEARBY="${DIRNAME}/../${test_dir}"
  if [ -d "$PARENT_NEARBY" ]; then
    for pattern in "${SEARCH_PATTERNS[@]}"; do
      if [ -f "${PARENT_NEARBY}/${pattern}" ]; then
        exit 0
      fi
    done
  fi
done

# -- Search strategy 3: Project-wide search ------------------------------------
# Broader search as fallback -- find any test file matching the base name

for pattern in "${SEARCH_PATTERNS[@]}"; do
  FOUND=$(find "$PROJECT_ROOT" -maxdepth 6 -name "$pattern" -type f -print -quit 2>/dev/null || true)
  if [ -n "$FOUND" ]; then
    exit 0
  fi
done

# -- No test found — block the edit --------------------------------------------

echo "TDD GATE: No tests found for '${FILENAME}'. Write tests BEFORE implementing."
echo "  Looked for: ${BASE_NAME}.test.*, ${BASE_NAME}Test.*, ${BASE_NAME}_test.*, test_${BASE_NAME}.*"
echo "  Searched: same directory, nearby test dirs, project-wide (maxdepth 6)"
echo ""
echo "  Create a test file first, then retry the edit."
exit 2
