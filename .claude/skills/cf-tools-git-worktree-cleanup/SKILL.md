---
name: cf-tools-git-worktree-cleanup
category: coding
description: When the user asks to clean up worktrees, remove merged branches, prune stale worktree directories, or tidy up after parallel development — activate this skill for worktree and branch cleanup
---

# Worktree Cleanup — Remove Merged Worktrees and Branches

Removes worktrees and their associated branches after work has been merged. Supports selective cleanup, dry-run preview, and force removal for abandoned branches.

## Activation

- User says "clean up worktrees", "remove merged branches", "prune stale worktrees"
- User says "I'm done with all the parallel tasks"
- User passes flags: `--all`, `--branch <name>`, `--dry-run`, `--force-all`

## Process

### 1. Validate Context

```bash
# Must run from the main repo, not from inside a worktree
GIT_DIR=$(git rev-parse --git-dir)
if [[ "$GIT_DIR" == *"/worktrees/"* ]]; then
  echo "ERROR: Run cleanup from the main repo, not from inside a worktree."
  echo "Switch to: $(git worktree list | head -1 | awk '{print $1}')"
  exit 1
fi
```

### 2. Parse Flags

| Flag | Behavior |
|------|----------|
| *(no flag)* | Interactive — show status, ask before each removal |
| `--all` | Remove all merged worktree branches (skip unmerged) |
| `--branch <name>` | Target a specific branch for removal |
| `--dry-run` | Show what would be removed without making changes |
| `--force-all` | Remove ALL worktree branches regardless of merge status |

### 3. Discover Worktree Branches

```bash
git fetch origin --quiet
git worktree list --porcelain
```

Filter for branches matching these patterns:
- `claude/*` — created by worktree-init
- `review/*` — created by review workflows

Skip the main working tree (the first entry in `git worktree list`).

### 4. Check Merge Status

For each candidate branch, determine if it has been merged:

```bash
# Method 1: Standard merge check
git branch --merged origin/main | grep -q "$BRANCH"

# Method 2: Squash-merge detection (diff is empty against main)
DIFF_COUNT=$(git diff origin/main..."$BRANCH" --stat | wc -l | tr -d ' ')
if [ "$DIFF_COUNT" -eq 0 ]; then
  echo "Squash-merged (empty diff against main)"
fi
```

Both methods are needed because squash merges don't appear in `--merged` output.

### 5. Display Status Table

```
Worktree Cleanup
================

| # | Branch                      | Merge Status   | Action       |
|---|-----------------------------|----------------|--------------|
| 1 | claude/fix-login-timeout    | Merged         | Will remove  |
| 2 | claude/add-retry-logic      | Squash-merged  | Will remove  |
| 3 | claude/update-docs          | NOT merged     | Skip         |
| 4 | review/pr-87-security       | Merged         | Will remove  |
```

In `--dry-run` mode, display the table and stop. In interactive mode (no flags), ask user to confirm before proceeding.

### 6. Remove Worktrees and Branches

For each branch marked for removal:

```bash
WORKTREE_PATH=$(git worktree list --porcelain | grep -B1 "branch refs/heads/$BRANCH" | head -1 | sed 's/worktree //')

# Remove the worktree directory
git worktree remove "$WORKTREE_PATH" --force

# Delete local branch
git branch -D "$BRANCH"

# Delete remote branch (if it exists)
git push origin --delete "$BRANCH" 2>/dev/null
```

### 7. Prune and Finalize

```bash
git worktree prune
git worktree list
```

## Output

### Removal Summary

```
Cleanup Complete
================

  Removed:  3 worktrees, 3 local branches, 2 remote branches
  Skipped:  1 (unmerged: claude/update-docs)
  Pruned:   1 stale worktree reference

Remaining worktrees:
  .  [main]
```

### Dry-Run Output

```
Dry Run — No changes made
==========================
Would remove:  claude/fix-login-timeout (merged), claude/add-retry-logic (squash-merged), review/pr-87-security (merged)
Would skip:    claude/update-docs (not merged — 2 commits ahead)
Run without --dry-run to execute.
```

## Gotchas

- **Must run from main repo**: Worktree removal from inside the worktree being removed will fail or leave orphaned state. Always enforce the main-repo check first.
- **Squash-merge detection**: `git branch --merged` only detects standard merges. The empty-diff check catches squash merges but can false-positive on manually rebased branches.
- **Remote branch deletion**: `git push origin --delete` fails if already deleted (GitHub auto-deletes on merge). The `2>/dev/null` handles this, but log it.
- **Force removal risks**: `--force-all` removes unmerged branches too. Always show the status table first so the user sees what will be lost.
- **Locked worktrees**: If a worktree is locked (`git worktree lock`), removal fails. Detect and inform the user to unlock first.
- **Stale refs**: If someone `rm -rf`'d a worktree directory without `git worktree remove`, `git worktree prune` cleans up the dangling reference.
- **Pattern matching**: Only clean up `claude/*` and `review/*` branches. Never touch `main`, `master`, `develop`, or user branches outside these patterns.
