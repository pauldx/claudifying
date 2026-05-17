---
name: cf-tools-git-worktree-deliver
category: coding
description: When the user asks to deliver a worktree, push and PR a worktree branch, ship the current task, commit and create a pull request from a worktree — activate this skill for worktree delivery workflow
---

# Worktree Deliver — Commit, Push, and PR

Takes the current worktree from working changes to a merged-ready pull request in one guided flow. Commits with a conventional message, pushes the branch, and creates a PR with context from the task file.

## Activation

- User says "deliver this worktree", "ship it", "push and PR", "I'm done with this task"
- User wants to wrap up a worktree branch and open a pull request
- User says "create PR from worktree"

## Process

### 1. Validate Context

```bash
# Confirm we're in a worktree, not the main repo
GIT_DIR=$(git rev-parse --git-dir)
if [[ "$GIT_DIR" != *"/worktrees/"* ]]; then
  echo "ERROR: Not inside a worktree. Run this from a worktree directory."
  exit 1
fi

BRANCH=$(git branch --show-current)
```

- If the branch is `main` or `master`, abort with a clear error
- If the working tree has no changes AND no commits ahead of main, warn that there's nothing to deliver

### 2. Read Task Context

```bash
TASK_FILE=".worktree-task.md"
if [ -f "$TASK_FILE" ]; then
  TASK_DESCRIPTION=$(sed -n '/^# Task/,/^##/{/^# Task/d;/^##/d;p}' "$TASK_FILE" | sed '/^$/d')
else
  TASK_DESCRIPTION="(no task file found — will generate PR description from commit diff)"
fi
```

### 3. Show Changes and Confirm

```bash
git diff --stat && git diff --cached --stat
git ls-files --others --exclude-standard
```

Display the summary and **ask user for confirmation** before proceeding.

### 4. Clean Up Task File and Stage

```bash
rm -f .worktree-task.md
```

Review `git status --short` output. Prefer staging specific files (`git add <file1> <file2>`) over `git add -A` to avoid accidentally including generated files, build artifacts, or secrets. Only use `git add -A` if the user explicitly confirms all changes should be included.

Show `git diff --cached --stat` after staging so the user sees what will be committed.

### 5. Generate Commit Message

Analyze `git diff --cached` to determine type (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`). Use the task description to inform the summary. Keep the first line under 72 characters. Add body bullets if multiple logical changes.

**Ask user for confirmation** before committing. Allow edits.

```bash
git commit -m "$(cat <<'EOF'
feat: <generated summary>

- <change detail 1>
- <change detail 2>

Task: <task description from .worktree-task.md>
EOF
)"
```

### 6. Push

```bash
git push -u origin HEAD
```

- If the push fails due to diverged history, show the error and suggest `git pull --rebase origin main` before retrying
- Never force-push without explicit user consent

### 7. Create Pull Request

```bash
gh pr create \
  --title "<conventional type>: <concise title>" \
  --body "$(cat <<'EOF'
## Summary

<2-3 bullet points describing what changed and why>

## Original Task

<task description from .worktree-task.md>

## Changes

<output of git diff --stat against main>

---
Created from worktree branch `<branch-name>`
EOF
)"
```

- If `gh` is not installed or not authenticated, fall back to printing the push URL and instructions for manual PR creation
- Set the base branch to `main` (or `master` if main doesn't exist)

## Output

```
Delivery Complete
=================

  Branch:   claude/fix-login-timeout
  Commit:   feat: fix session timeout by extending idle TTL to 5m
  PR:       https://github.com/org/repo/pull/42
  Status:   Ready for review

Next steps:
  - Review the PR and request reviewers
  - Return to main repo: cd <main-repo-path>
  - Clean up this worktree later with /labs-coding:worktree-cleanup
```

## Gotchas

- **Not in a worktree**: The most common mistake. Always check `git rev-parse --git-dir` for the `/worktrees/` path segment before proceeding.
- **Empty delivery**: If there are no changes and no commits ahead of main, there's nothing to deliver. Detect this early and exit cleanly.
- **Task file in commit**: The `.worktree-task.md` must be removed BEFORE staging. If it gets committed, the PR will contain metadata that shouldn't be in the codebase.
- **Push rejection**: If someone else pushed to the same branch (unlikely with `claude/` prefix but possible), the push will fail. Never auto-force-push.
- **gh auth**: `gh pr create` requires authentication. If `gh auth status` fails, provide the manual alternative immediately rather than failing cryptically.
- **Large diffs**: If the diff is very large (100+ files), summarize rather than dumping the full stat into the PR body. Use `git diff --stat | head -20` with a truncation note.
- **Two confirmations required**: Always pause for user approval (1) after showing changes before staging, and (2) after generating the commit message before committing. Never auto-commit without consent.
