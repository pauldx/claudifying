---
name: cf-tools-git-worktree-init
category: coding
description: When the user asks to create parallel worktrees, set up multi-task branches, spin up isolated workspaces for concurrent development, or split work across terminals — activate this skill for git worktree initialization
---

# Worktree Init — Parallel Multi-Task Setup

Creates isolated git worktrees from a pipe-separated task list so you can work on multiple features simultaneously in separate terminal sessions.

## Activation

- User says "set up worktrees for these tasks", "spin up parallel branches", "I need to work on 3 things at once"
- User provides a pipe-separated list: `task 1 | task 2 | task 3`
- User wants concurrent Claude sessions on different features

## Process

### 1. Validate Environment

```bash
# Confirm we're in a git repo and on a clean working tree
git rev-parse --is-inside-work-tree
git status --porcelain
```

- If there are uncommitted changes, warn the user and ask whether to stash or abort
- Determine the repo name from the directory basename

### 2. Parse Task List

- Split input on `|` delimiter, trim whitespace from each task
- Generate a kebab-case branch name for each: `claude/<task-as-kebab>`
- Example: `fix login timeout | add retry logic | update docs` becomes:
  - `claude/fix-login-timeout`
  - `claude/add-retry-logic`
  - `claude/update-docs`

### 3. Fetch and Create Worktrees

```bash
git fetch origin

# For each task:
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
BRANCH="claude/<kebab-name>"
WORKTREE_PATH="../worktrees/${REPO_NAME}/${BRANCH}"

git worktree add -b "$BRANCH" "$WORKTREE_PATH" origin/main
```

- If the branch already exists, skip creation and notify the user
- If `origin/main` doesn't exist, try `origin/master` as fallback

### 4. Write Task File

Write `.worktree-task.md` inside each new worktree:

```markdown
# Task

<original task description from the pipe-separated input>

## Branch

`claude/<kebab-name>`

## Created

<ISO timestamp>
```

### 5. Detect Package Manager

Check each worktree root for lock files and note what needs installing:

```bash
# Check in priority order
[ -f "package-lock.json" ] && echo "Run: npm install"
[ -f "yarn.lock" ] && echo "Run: yarn install"
[ -f "pnpm-lock.yaml" ] && echo "Run: pnpm install"
[ -f "Pipfile.lock" ] && echo "Run: pipenv install"
[ -f "poetry.lock" ] && echo "Run: poetry install"
[ -f "go.sum" ] && echo "Run: go mod download"
```

## Output

### Summary Table

```
| # | Task                | Branch                      | Path                                        | Status  |
|---|---------------------|-----------------------------|---------------------------------------------|---------|
| 1 | fix login timeout   | claude/fix-login-timeout    | ../worktrees/myrepo/claude/fix-login-timeout | Created |
| 2 | add retry logic     | claude/add-retry-logic      | ../worktrees/myrepo/claude/add-retry-logic   | Created |
| 3 | update docs         | claude/update-docs          | ../worktrees/myrepo/claude/update-docs       | Skipped |
```

### Ready-to-Copy Commands

```bash
# Terminal 1 — fix login timeout
cd ../worktrees/myrepo/claude/fix-login-timeout && claude

# Terminal 2 — add retry logic
cd ../worktrees/myrepo/claude/add-retry-logic && claude

# Terminal 3 — update docs
cd ../worktrees/myrepo/claude/update-docs && claude
```

Remind the user: **Ghostty split panels** — use `Cmd+D` for vertical split, `Cmd+Shift+D` for horizontal split to run sessions side by side.

### Package Install Notes

If lock files were detected, list the install commands needed per worktree before starting work.

## Gotchas

- **Dirty working tree**: Worktree creation fails if there are uncommitted changes in the index. Always check `git status --porcelain` first.
- **Branch already exists**: `git worktree add -b` fails if the branch name is taken. Detect and skip gracefully, or offer to reuse the existing worktree.
- **Nested worktree paths**: Never create a worktree inside another git repo's tree. The `../worktrees/` convention avoids this.
- **Detached HEAD on main**: If the main repo is in detached HEAD state, worktree creation from `origin/main` still works but the user should be warned.
- **Package installs are per-worktree**: Each worktree has its own `node_modules` / virtualenv. Dependencies must be installed separately in each one.
- **Worktree limit**: Git has no hard limit, but more than 5-6 simultaneous worktrees gets unwieldy. Warn if the task list exceeds 6 items.
