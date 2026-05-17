---
name: cf-tools-git-undo-last
description: "Undo the last commit safely — soft reset keeps changes staged. Trigger: /cf-tools-git-undo-last"
trigger: /cf-tools-git-undo-last
version: 1.0.0
---

# /cf-tools-git-undo-last

Soft-reset the most recent commit on the current branch. Changes from the discarded commit remain in the index (staged) so the user can re-edit the commit message, re-stage selectively, or amend. **Never** uses `--hard` by default — that destroys work silently.

## Usage

```
/cf-tools-git-undo-last                    # dry-run preview by default
/cf-tools-git-undo-last --execute          # actually soft-reset HEAD~1
/cf-tools-git-undo-last --keep-changes     # alias for --execute (default mode)
/cf-tools-git-undo-last --keep-staged      # same as --execute
/cf-tools-git-undo-last --discard          # HARD reset (destructive, requires --force)
/cf-tools-git-undo-last --discard --force  # confirmed hard reset
/cf-tools-git-undo-last -n 3 --execute     # undo last 3 commits, keep changes
```

Flags:

| Flag | Behavior |
|------|----------|
| *(none)* | Dry-run — show what would be undone, no mutation |
| `--execute` / `--keep-changes` | Run `git reset --soft HEAD~N`. Files stay staged. |
| `--mixed` | Run `git reset --mixed HEAD~N`. Files unstaged but kept in working tree. |
| `--discard` + `--force` | Run `git reset --hard HEAD~N`. **Destroys** uncommitted work. |
| `-n <count>` | Number of commits to undo (default `1`). |

## What You Must Do When Invoked

### Step 1 — Pre-flight check

```bash
# Verify we're in a git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: not a git repo"; exit 1; }

# Verify HEAD has parent(s) for the count requested
N="${COUNT:-1}"
if ! git rev-parse --verify "HEAD~${N}" >/dev/null 2>&1; then
  echo "ERROR: cannot undo ${N} commit(s) — not enough history"
  exit 1
fi

# Refuse if the commit has been pushed AND --force is not set
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "")
if [ -n "$UPSTREAM" ]; then
  AHEAD=$(git rev-list --count "${UPSTREAM}..HEAD")
  if [ "$AHEAD" -lt "$N" ]; then
    echo "⚠️  WARNING: $((N - AHEAD)) of the commits to undo have been pushed to $UPSTREAM."
    echo "   Undoing them locally will require a force-push later, which rewrites shared history."
    [ "$FORCE" != "1" ] && { echo "   Re-run with --force to acknowledge."; exit 1; }
  fi
fi
```

### Step 2 — Show preview

```bash
echo "=== Commits that will be undone (newest first) ==="
git log --oneline -n "$N"

echo ""
echo "=== Files affected ==="
git diff --stat "HEAD~${N}" HEAD

echo ""
echo "=== HEAD after reset will be ==="
git log --oneline -1 "HEAD~${N}"
```

If no `--execute`/`--discard` flag was passed, stop here — dry-run only.

### Step 3 — Execute reset

```bash
if [ "$MODE" = "discard" ]; then
  [ "$FORCE" != "1" ] && { echo "ERROR: --discard requires --force"; exit 1; }
  echo "⚠️  HARD reset — uncommitted work in tracked files will be lost."
  git reset --hard "HEAD~${N}"
elif [ "$MODE" = "mixed" ]; then
  git reset --mixed "HEAD~${N}"
else
  # default soft
  git reset --soft "HEAD~${N}"
fi
```

### Step 4 — Report new state

```bash
echo "=== After reset ==="
git log --oneline -3
echo ""
echo "=== Index / working tree ==="
git status --short
```

Tell the user how to recover if needed: `git reflog` shows the previous HEAD, and `git reset --soft <sha>` rewinds back.

## Output Contract

```
## Undo last commit

**Mode:**          soft | mixed | hard
**Commits undone:** N
**Old HEAD:**       <abbrev sha> <subject>
**New HEAD:**       <abbrev sha> <subject>
**Recovery:**       git reset --soft <old sha>   (visible in `git reflog`)
**Files staged:**   <count>     (soft mode only)
**Pushed?:**        yes/no — force-push needed if yes
```

## Gotchas

- **Default is dry-run, not action.** Never auto-execute — wait for `--execute`.
- **Hard reset is gated behind two flags** (`--discard --force`). One flag alone refuses.
- **Pushed commits warning is non-fatal only with `--force`.** Rewriting public history is a team-wide event.
- **`git reflog` is the safety net.** Even after `--hard`, the old SHA stays in reflog for ~90 days by default. Always mention it in the recovery line.
- **Merge commits:** `HEAD~1` walks the first parent. To undo a merge cleanly use `git reset --merge` or `git revert -m 1 <merge-sha>` instead — warn the user when `git log -1 --pretty=%P HEAD | wc -w` returns 2.
- **Detached HEAD:** if `git symbolic-ref HEAD` fails, refuse — undoing in detached HEAD orphans the commit immediately.

## Cross-Platform Notes

- All commands are standard git 2.0+; works identically on macOS, Linux, WSL, Windows Git Bash.
- The `--force-with-lease` flag is recommended over `--force` when the user later force-pushes (mention this in output).
