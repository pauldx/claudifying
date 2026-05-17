#!/bin/bash
# Scope Guard — Stop event hook
# Compares git-modified files against files declared in the active .spec.md.
# Warns about out-of-scope modifications. Non-blocking (always exits 0).
#
# Reads stdin for tool input context (Stop event payload).

set -euo pipefail

# -- Determine project root ----------------------------------------------------

PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

if [ -z "$PROJECT_DIR" ]; then
  # Not in a git repo -- nothing to check
  exit 0
fi

# -- Collect modified files from git -------------------------------------------

UNSTAGED=$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null || true)
STAGED=$(git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null || true)

# Combine and deduplicate
MODIFIED_FILES=$(printf "%s\n%s" "$UNSTAGED" "$STAGED" | sort -u | grep -v '^$' || true)

if [ -z "$MODIFIED_FILES" ]; then
  # No modified files -- nothing to check
  exit 0
fi

# -- Find the most recently modified .spec.md ----------------------------------
# Look for specs modified within the last 60 minutes (active session window)

SPEC_FILE=$(find "$PROJECT_DIR" -name "*.spec.md" -type f -mmin -60 2>/dev/null | while read -r f; do
  echo "$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0) $f"
done | sort -rn | head -1 | awk '{print $2}')

if [ -z "$SPEC_FILE" ]; then
  # No recently modified spec -- skip scope check
  exit 0
fi

# -- Extract declared files from spec ------------------------------------------
# Parse the "Files to Create/Modify" section: grab lines starting with "- " after the header

IN_SECTION=false
DECLARED_FILES=""

while IFS= read -r line; do
  # Detect the section header (case-insensitive, flexible wording)
  if echo "$line" | grep -qiE "^#+\s*(Files to (Create|Modify)|Files to Create/Modify|Affected Files|Changed Files)"; then
    IN_SECTION=true
    continue
  fi

  # Stop at the next header
  if $IN_SECTION && echo "$line" | grep -qE "^#+\s"; then
    IN_SECTION=false
    continue
  fi

  # Collect file paths from list items
  if $IN_SECTION && echo "$line" | grep -qE "^\s*-\s"; then
    # Strip the leading "- " and any backticks, trim whitespace
    FILE_ENTRY=$(echo "$line" | sed 's/^\s*-\s*//' | sed 's/`//g' | sed 's/\s*$//' | sed 's/^\s*//')
    if [ -n "$FILE_ENTRY" ]; then
      DECLARED_FILES="${DECLARED_FILES}${FILE_ENTRY}"$'\n'
    fi
  fi
done < "$SPEC_FILE"

if [ -z "$DECLARED_FILES" ]; then
  # No declared files in spec -- can't do scope comparison
  exit 0
fi

# -- Compare modified files against declared list ------------------------------

OUT_OF_SCOPE=""

while IFS= read -r modified; do
  [ -z "$modified" ] && continue

  # Skip files that are commonly modified alongside any feature
  # Test files
  if echo "$modified" | grep -qiE "(test|spec|_test\.|\.test\.|Test\.)" ; then
    continue
  fi
  # Test directories
  if echo "$modified" | grep -qE "/(test|tests|__tests__)/" ; then
    continue
  fi
  # Config files
  if echo "$modified" | grep -qiE "\.(json|yaml|yml|toml|xml|ini|cfg|conf|env|lock)$" ; then
    continue
  fi
  # Infrastructure
  if echo "$modified" | grep -qiE "(Dockerfile|docker-compose|Makefile|\.tf$|\.hcl$|\.github/)" ; then
    continue
  fi
  # Documentation
  if echo "$modified" | grep -qiE "\.(md|txt|rst|adoc)$" ; then
    continue
  fi
  # Package manager lockfiles and manifests
  if echo "$modified" | grep -qiE "(package-lock|yarn\.lock|Cargo\.lock|go\.sum|Pipfile\.lock)" ; then
    continue
  fi

  # Check if this file is declared in the spec
  IS_DECLARED=false
  while IFS= read -r declared; do
    [ -z "$declared" ] && continue
    # Substring match: declared path should appear in the modified path
    if echo "$modified" | grep -qF "$declared"; then
      IS_DECLARED=true
      break
    fi
    # Also check reverse: modified path appears in declared path
    if echo "$declared" | grep -qF "$modified"; then
      IS_DECLARED=true
      break
    fi
  done <<< "$DECLARED_FILES"

  if ! $IS_DECLARED; then
    OUT_OF_SCOPE="${OUT_OF_SCOPE}  - ${modified}"$'\n'
  fi
done <<< "$MODIFIED_FILES"

# -- Report results ------------------------------------------------------------

if [ -n "$OUT_OF_SCOPE" ]; then
  echo "SCOPE GUARD: The following modified files are NOT declared in the active spec:"
  echo "$OUT_OF_SCOPE"
  echo "  Active spec: $(basename "$SPEC_FILE")"
  echo ""
  echo "  If these changes are intentional, update your .spec.md to include them."
  echo "  If they are accidental, consider reverting them."
  echo ""
  echo "  This is a warning, not a blocker."
fi

# Non-blocking -- always allow
exit 0
