---
name: cf-tools-git-worktree-check
category: coding
description: When the user asks to check worktree status, see what branches are active, review progress across parallel tasks, or inspect the current worktree state — activate this skill for worktree status reporting
---

# Worktree Check — Status Dashboard

Shows the current state of git worktrees: which branch you're on, what task you're working on, how far ahead of main you are, and the state of your working directory.

## Activation

- User says "check worktree status", "where am I?", "what's my worktree doing?"
- User says "show all worktrees", "list active branches"
- User wants a quick progress snapshot before delivering or switching context

## Process

### 1. Detect Context

```bash
# Determine if we're in a worktree or the main repo
git worktree list
TOPLEVEL=$(git rev-parse --show-toplevel)
GIT_DIR=$(git rev-parse --git-dir)
```

- If `GIT_DIR` contains `/worktrees/`, we're inside a worktree — show single-worktree detail view
- If `GIT_DIR` ends with `/.git`, we're in the main repo — show multi-worktree overview

### 2. Single Worktree View (Inside a Worktree)

Gather details about the current worktree:

```bash
# Branch name
BRANCH=$(git branch --show-current)

# Task from .worktree-task.md
TASK="(no task file found)"
[ -f ".worktree-task.md" ] && TASK=$(sed -n '/^# Task/,/^##/{/^# Task/d;/^##/d;p}' .worktree-task.md | head -3)

# Commits ahead of main
git fetch origin --quiet
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")

# Working directory state
MODIFIED=$(git diff --name-only | wc -l | tr -d ' ')
STAGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
UNTRACKED=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')
```

### 3. Multi-Worktree Overview (From Main Repo)

List all worktrees and gather summary info for each:

```bash
git worktree list --porcelain
```

For each worktree path, extract:
- Branch name from the `branch` line
- Whether a `.worktree-task.md` exists and its task title
- Commit count ahead of main
- Whether the working directory is clean or dirty

## Output

### Single Worktree View

```
Worktree Status
===============

  Branch:     claude/fix-login-timeout
  Task:       Fix the login timeout that occurs after 30s idle
  Commits:    3 ahead of origin/main
  Modified:   2 files
  Staged:     1 file
  Untracked:  0 files
  Path:       ../worktrees/myrepo/claude/fix-login-timeout
```

If there are commits ahead, also show a condensed log:

```bash
git log --oneline origin/main..HEAD
```

### Multi-Worktree Overview

```
Active Worktrees
================

| # | Branch                      | Task                  | Ahead | Dirty | Path                              |
|---|-----------------------------|-----------------------|-------|-------|-----------------------------------|
| 1 | main                        | (main repo)           | —     | No    | .                                 |
| 2 | claude/fix-login-timeout    | Fix login timeout     | 3     | Yes   | ../worktrees/myrepo/claude/fix-…  |
| 3 | claude/add-retry-logic      | Add retry logic       | 1     | No    | ../worktrees/myrepo/claude/add-…  |
| 4 | claude/update-docs          | Update documentation  | 0     | No    | ../worktrees/myrepo/claude/upda…  |
```

### Quick Actions

After displaying the status, suggest relevant next steps:

- If commits are ahead and working tree is clean: "Ready to deliver — run `/labs-coding:worktree-deliver`"
- If working tree is dirty: "Uncommitted changes detected — commit or stash before delivering"
- If 0 commits ahead: "No changes yet on this branch"

## Gotchas

- **Fetch before counting**: Always `git fetch origin --quiet` before `rev-list --count` to get accurate ahead/behind numbers. Stale remote refs give misleading counts.
- **Missing task file**: Not every worktree will have `.worktree-task.md` (manually created branches won't). Handle gracefully with a fallback message.
- **Worktree path parsing**: `git worktree list --porcelain` output uses `worktree <path>` lines. Parse carefully — paths with spaces need quoting.
- **Pruned worktrees**: If a worktree directory was deleted without `git worktree remove`, it shows as prunable. Flag these distinctly.
- **Bare repos**: `git worktree list` in a bare repo has different output. This skill assumes a standard (non-bare) clone.
- **Performance**: Running `git rev-list` for many worktrees can be slow on large repos. Batch the fetch and keep per-worktree checks lightweight.
