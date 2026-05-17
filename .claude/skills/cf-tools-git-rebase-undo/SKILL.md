---
name: cf-tools-git-rebase-undo
description: "Recover from a botched rebase via git reflog — find pre-rebase HEAD and reset back. Trigger: /cf-tools-git-rebase-undo"
trigger: /cf-tools-git-rebase-undo
version: 1.0.0
---

# /cf-tools-git-rebase-undo

Recover a branch from a failed or undesired rebase. Inspects `git reflog` for the pre-rebase commit, presents candidates ranked by likelihood, and resets the branch back. **Dry-run by default** — never resets without `--execute`.

## Usage

```
/cf-tools-git-rebase-undo                  # show candidates, no mutation
/cf-tools-git-rebase-undo --execute        # reset to top-ranked candidate
/cf-tools-git-rebase-undo --sha <abbrev>   # reset to a specific reflog entry
/cf-tools-git-rebase-undo --execute --backup   # create rescue/<branch>-<ts> tag first
```

Flags:

| Flag | Behavior |
|------|----------|
| *(none)* | Dry-run preview of candidates |
| `--execute` | `git reset --hard <chosen>` after user confirms |
| `--sha <ref>` | Choose specific reflog entry instead of auto-ranking |
| `--backup` | Tag current HEAD as `rescue/<branch>-<unix-ts>` before reset |
| `--limit N` | Show N reflog entries (default 30) |

## Why reflog Works

`git rebase` is destructive — it writes new commit SHAs and moves the branch ref. But the OLD branch tip stays in `HEAD@{N}` reflog entries until garbage collection (~90 days). Finding the right entry is mechanical:

- Entries labeled `rebase (start)`, `rebase (finish)`, `rebase -i (start)` bracket the rebase event.
- The commit just before `rebase (start)` is the original pre-rebase tip — **that is the recovery target**.

## What You Must Do When Invoked

### Step 1 — Survey reflog

```bash
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: not a git repo"; exit 1; }
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")

echo "=== Current branch: $BRANCH ==="
echo "=== Reflog (last ${LIMIT:-30} entries) ==="
git reflog -n "${LIMIT:-30}"
```

### Step 2 — Identify rebase boundaries

```bash
# Find the most recent "rebase (start)" entry
START_LINE=$(git reflog | grep -n -E 'rebase( -i)?\s*\(start\)' | head -1)

if [ -z "$START_LINE" ]; then
  echo "⚠️  No 'rebase (start)' marker found in reflog."
  echo "   Possible causes: rebase was older than reflog retention, or it wasn't a rebase."
  echo "   Falling back to listing all recent reflog entries — pick one with --sha."
fi

# The entry IMMEDIATELY BEFORE rebase (start) is the pre-rebase HEAD
INDEX=$(echo "$START_LINE" | cut -d: -f1)
PRE_REBASE_IDX=$((INDEX))   # reflog @{N} where N = lines above start; calculate precisely
```

In practice, compute the `@{N}` offset by counting reflog entries above the `rebase (start)` line. Show the candidate commit:

```bash
CANDIDATE=$(git reflog | sed -n "$((INDEX + 1))p" | awk '{print $1}')
echo ""
echo "=== Top candidate: $CANDIDATE ==="
git show --stat --no-patch "$CANDIDATE"
```

### Step 3 — Present ranked candidates

```
Rebase Undo Candidates
======================

| Rank | Reflog ref       | SHA      | Subject                              | Heuristic         |
|------|------------------|----------|--------------------------------------|-------------------|
| 1    | HEAD@{4}         | ee3b88e  | feat: add line 3                     | pre rebase(start) |
| 2    | HEAD@{7}         | f56af5d  | fix: line 2                          | before merge      |
| 3    | HEAD@{12}        | aa34679  | feat: initial                        | branch start      |

Default: rank-1 (HEAD@{4}). Override with --sha <abbrev>.
```

Heuristics for ranking:
- **Rank 1**: entry immediately before the most recent `rebase (start)`.
- **Rank 2**: entries before older `rebase (start)` or `merge` events.
- **Rank 3+**: long-lived snapshots (chronological older entries).

### Step 4 — Confirm and execute

```bash
if [ "$EXECUTE" != "1" ]; then
  echo ""
  echo "Dry-run. Re-run with --execute to reset $BRANCH to $CHOSEN."
  exit 0
fi

# Optional backup tag
if [ "$BACKUP" = "1" ]; then
  TAG="rescue/${BRANCH}-$(date +%s)"
  git tag "$TAG"
  echo "✅ Backed up current HEAD as tag: $TAG"
fi

# The hard reset
git reset --hard "$CHOSEN"
echo "✅ Reset $BRANCH → $CHOSEN"
```

### Step 5 — Verify

```bash
echo ""
echo "=== New HEAD ==="
git log --oneline -5
echo ""
echo "=== Reflog now shows recovery point ==="
git reflog -3
```

## Output Contract

```
## Rebase Undo

**Branch:**         <branch-name>
**Pre-rebase SHA:** <abbrev>  <subject>
**Backup tag:**     rescue/<branch>-<unix-ts>   (if --backup)
**Action:**         dry-run | reset executed
**Recovery (if regret):** git reset --hard <old-sha-from-reflog>
```

## Gotchas

- **Always `--backup` before destructive resets in shared branches.** A rescue tag costs nothing and saves agonizing recovery later.
- **`git reflog` is local-only.** If the rebase happened on another machine or after a fresh clone, reflog won't show it. Try `git fsck --lost-found` for dangling commits.
- **Multiple rebases compound.** If the user rebased twice, only the most recent `rebase (start)` is detected by default. Use `--sha` to target an older entry manually.
- **Interactive rebases (`-i`) show different markers.** Look for `rebase -i (start)` and `rebase -i (finish)`.
- **Working tree must be clean.** `git reset --hard` discards uncommitted changes silently — pre-flight with `git status --short` and refuse if dirty unless `--force`.
- **Don't confuse with `git rebase --abort`.** If the rebase is still in progress (`.git/rebase-merge/` exists), recommend `--abort` first; this skill is for AFTER the rebase completed.

## Cross-Platform Notes

- Reflog retention defaults: 90 days for reachable, 30 days for unreachable. On Windows Git Bash and macOS this is identical.
- On case-insensitive filesystems (macOS HFS+/APFS default), branch names like `Feature` and `feature` collide — verify with `git branch --list` exact-match before reset.
