---
name: cf-tools-git-conflict-helper
description: "List unresolved merge conflicts, open files in $EDITOR, and run --abort/--continue helpers. Trigger: /cf-tools-git-conflict-helper"
trigger: /cf-tools-git-conflict-helper
version: 1.0.0
---

# /cf-tools-git-conflict-helper

Locate every unresolved merge/rebase/cherry-pick conflict, open the files in `$EDITOR`, and offer one-shot `--abort` or `--continue` helpers.

## Usage

```
/cf-tools-git-conflict-helper             # list conflicts + offer actions
/cf-tools-git-conflict-helper --open      # list + open each file in $EDITOR
/cf-tools-git-conflict-helper --abort     # abort the in-progress merge/rebase/cherry-pick
/cf-tools-git-conflict-helper --continue  # stage all and continue (after resolution)
/cf-tools-git-conflict-helper --diff      # show conflict markers in pretty diff
/cf-tools-git-conflict-helper --ours <path>     # accept "ours" for one file
/cf-tools-git-conflict-helper --theirs <path>   # accept "theirs" for one file
```

## What You Must Do When Invoked

### Step 1 — Detect operation in progress

```bash
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || { echo "ERROR: not a git repo"; exit 1; }

OP=""
[ -f "$GIT_DIR/MERGE_HEAD" ]        && OP="merge"
[ -d "$GIT_DIR/rebase-merge" ]      && OP="rebase"
[ -d "$GIT_DIR/rebase-apply" ]      && OP="rebase-apply"
[ -f "$GIT_DIR/CHERRY_PICK_HEAD" ]  && OP="cherry-pick"
[ -f "$GIT_DIR/REVERT_HEAD" ]       && OP="revert"

if [ -z "$OP" ]; then
  echo "No merge/rebase/cherry-pick/revert in progress."
  # Still list any unmerged paths in case the user is in an odd state
fi

echo "Operation in progress: ${OP:-none}"
```

### Step 2 — List unresolved conflicts

```bash
echo ""
echo "=== Unresolved files ==="
# 'git diff --name-only --diff-filter=U' lists exactly the unmerged paths
CONFLICTS=$(git diff --name-only --diff-filter=U)

if [ -z "$CONFLICTS" ]; then
  echo "✅ No conflicts. Working tree is clean of unmerged paths."
  if [ -n "$OP" ]; then
    echo "   You may be ready to run: /cf-tools-git-conflict-helper --continue"
  fi
  exit 0
fi

echo "$CONFLICTS" | nl -ba
echo ""
echo "=== Conflict marker counts per file ==="
for f in $CONFLICTS; do
  COUNT=$(grep -c '^<<<<<<<' "$f" 2>/dev/null || echo 0)
  echo "  [$COUNT hunk(s)] $f"
done
```

### Step 3 — Open in $EDITOR (if --open)

```bash
if [ "$OPEN" = "1" ]; then
  EDITOR="${EDITOR:-${VISUAL:-vi}}"
  echo ""
  echo "Opening ${CONFLICT_COUNT} file(s) in $EDITOR..."
  # shellcheck disable=SC2086
  $EDITOR $CONFLICTS
fi
```

### Step 4 — Single-file resolution helpers

```bash
if [ -n "$OURS_FILE" ]; then
  git checkout --ours "$OURS_FILE" && git add "$OURS_FILE"
  echo "✅ Took 'ours' for $OURS_FILE"
fi
if [ -n "$THEIRS_FILE" ]; then
  git checkout --theirs "$THEIRS_FILE" && git add "$THEIRS_FILE"
  echo "✅ Took 'theirs' for $THEIRS_FILE"
fi
```

### Step 5 — Abort / Continue

```bash
if [ "$ABORT" = "1" ]; then
  case "$OP" in
    merge)        git merge --abort ;;
    rebase|rebase-apply) git rebase --abort ;;
    cherry-pick)  git cherry-pick --abort ;;
    revert)       git revert --abort ;;
    *) echo "Nothing to abort." ;;
  esac
fi

if [ "$CONTINUE" = "1" ]; then
  # Sanity: ensure no conflict markers remain
  REMAINING=$(git diff --name-only --diff-filter=U | wc -l | tr -d ' ')
  if [ "$REMAINING" -gt 0 ]; then
    echo "ERROR: $REMAINING file(s) still unresolved. Resolve and re-run."
    exit 1
  fi
  # Verify no conflict markers in tracked files
  if git grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- ':!*.md' 2>/dev/null; then
    echo "⚠️  Conflict markers still present in tracked files (above). Fix before continuing."
    exit 1
  fi
  case "$OP" in
    merge)        git commit --no-edit ;;
    rebase|rebase-apply) git rebase --continue ;;
    cherry-pick)  git cherry-pick --continue ;;
    revert)       git revert --continue ;;
  esac
fi
```

### Step 6 — Pretty diff (if --diff)

```bash
if [ "$DIFF" = "1" ]; then
  echo ""
  echo "=== Conflict hunks ==="
  for f in $CONFLICTS; do
    echo "--- $f ---"
    # Show only the conflict regions with line numbers
    awk '/^<<<<<<</,/^>>>>>>>/' "$f" | nl -ba
    echo ""
  done
fi
```

## Output Contract

```
## Conflict Helper

**Operation:**   merge | rebase | cherry-pick | revert | none
**Unresolved:**  <count> file(s)
  - path/to/file1.ts  (3 hunk(s))
  - path/to/file2.py  (1 hunk(s))
**Action taken:** open in $EDITOR | --ours <f> | --theirs <f> | --abort | --continue | listed only
**Next step:**   git add <files> && /cf-tools-git-conflict-helper --continue
```

## Gotchas

- **`git diff --name-only --diff-filter=U`** is the canonical way to list unmerged paths — more reliable than parsing `git status --porcelain` for `UU`, `AA`, `DD` codes.
- **`--continue` checks for residual `<<<<<<<` markers** in tracked files. Markers in documentation/test fixtures (`.md`, `.txt`) can be false positives — exclude with `git grep -- ':!*.md' ':!*.txt'` and warn the user if the false-positive count is high.
- **`git checkout --ours/--theirs` semantics flip during rebase.** In a regular merge, "ours" = current branch. In a rebase, "ours" = the branch being rebased ONTO (the upstream). Always print which is which based on `$OP`.
- **Don't auto-continue.** Always require explicit `--continue` flag from the user — silent continuation after partial resolution corrupts history.
- **Binary files in conflict:** `git diff` won't show useful markers. List them separately and suggest `git checkout --ours <file>` or `--theirs <file>`.
- **`$EDITOR` may be unset.** Fall back to `$VISUAL`, then `vi`. On macOS/Linux dev machines, also probe `code -w` if user has VS Code (`command -v code`).

## Cross-Platform Notes

- macOS: `$EDITOR` often unset by default in non-interactive shells; explicit fallback to `vi` is required.
- Windows Git Bash: forward-slash paths from `git diff --name-only` work in PowerShell, CMD, and Bash equally.
- WSL: prefer `code -w` if the user has Windows VS Code reachable via PATH (`which code.exe`).
