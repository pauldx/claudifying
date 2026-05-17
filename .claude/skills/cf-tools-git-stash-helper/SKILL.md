---
name: cf-tools-git-stash-helper
description: "List, preview, apply, drop stashes — supports named stashes and auto-stash-before-pull. Trigger: /cf-tools-git-stash-helper"
trigger: /cf-tools-git-stash-helper
version: 1.0.0
---

# /cf-tools-git-stash-helper

Friendlier interface to `git stash`. Lists stashes with previews, applies/drops by name or index, creates named stashes, and offers a guarded auto-stash workflow for `git pull` on a dirty tree.

## Usage

```
/cf-tools-git-stash-helper                          # list stashes with file counts
/cf-tools-git-stash-helper --preview <ref>          # show full diff for one stash
/cf-tools-git-stash-helper --push "<name>"          # named save (git stash push -m)
/cf-tools-git-stash-helper --push "<name>" --include-untracked
/cf-tools-git-stash-helper --apply <ref>            # apply, keep stash entry
/cf-tools-git-stash-helper --pop <ref>              # apply and drop entry
/cf-tools-git-stash-helper --drop <ref>             # delete stash entry
/cf-tools-git-stash-helper --clear                  # delete ALL stashes (requires --force)
/cf-tools-git-stash-helper --auto-pull              # safe-stash, pull, pop
/cf-tools-git-stash-helper --by-name "<name>"       # resolve named stash to ref
```

`<ref>` may be a numeric index (`0`, `1`, ...), the standard form (`stash@{0}`), or — when a stash was saved with `--push -m` — its name (resolved via `--by-name`).

## What You Must Do When Invoked

### Step 1 — List with preview

```bash
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: not a git repo"; exit 1; }

COUNT=$(git stash list | wc -l | tr -d ' ')
if [ "$COUNT" = "0" ]; then
  echo "No stashes. Use --push \"<name>\" to create one."
  exit 0
fi

echo "=== Stashes ($COUNT) ==="
git stash list --pretty=format:'%C(yellow)%gd%Creset  %C(green)(%cr)%Creset  %s'
echo ""

# Per-stash file count
echo "=== Files per stash ==="
for i in $(seq 0 $((COUNT - 1))); do
  FILES=$(git stash show --name-only "stash@{$i}" 2>/dev/null | wc -l | tr -d ' ')
  echo "  stash@{$i}: $FILES file(s)"
done
```

### Step 2 — Resolve a stash reference

A user may pass `0`, `stash@{0}`, or a name like `"wip-feature-x"`. Normalize:

```bash
resolve_stash() {
  local input="$1"
  # Numeric index
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    echo "stash@{$input}"; return 0
  fi
  # Already in stash@{N} form
  if [[ "$input" =~ ^stash@\{[0-9]+\}$ ]]; then
    echo "$input"; return 0
  fi
  # Name lookup: scan stash list messages
  local idx
  idx=$(git stash list --pretty=format:'%gd %s' | grep -F " $input" | head -1 | awk '{print $1}')
  if [ -n "$idx" ]; then
    echo "$idx"; return 0
  fi
  echo "ERROR: cannot resolve stash reference: $input" >&2
  return 1
}
```

### Step 3 — Preview a stash

```bash
if [ -n "$PREVIEW" ]; then
  REF=$(resolve_stash "$PREVIEW") || exit 1
  echo "=== $REF ==="
  git stash show -p --stat "$REF"
fi
```

### Step 4 — Named push

```bash
if [ -n "$PUSH_NAME" ]; then
  ARGS=( stash push -m "$PUSH_NAME" )
  [ "$INCLUDE_UNTRACKED" = "1" ] && ARGS+=( --include-untracked )
  [ "$KEEP_INDEX" = "1" ] && ARGS+=( --keep-index )
  git "${ARGS[@]}"
  echo "✅ Stashed as: $PUSH_NAME → $(git stash list | head -1)"
fi
```

Use `--include-untracked` when the user has new files that aren't yet tracked but should travel with the stash. Use `--keep-index` to stash only unstaged changes while leaving the index intact (handy before running tests on the staged set).

### Step 5 — Apply / pop / drop

```bash
if [ -n "$APPLY" ]; then
  REF=$(resolve_stash "$APPLY") || exit 1
  git stash apply "$REF"
  echo "✅ Applied $REF (still in stash list)"
fi

if [ -n "$POP" ]; then
  REF=$(resolve_stash "$POP") || exit 1
  # Pop is apply+drop in one step. If apply fails on conflicts, git stops without dropping.
  if git stash pop "$REF"; then
    echo "✅ Popped $REF (removed from list)"
  else
    echo "⚠️  Conflicts during pop — stash entry preserved. Resolve, then drop manually."
  fi
fi

if [ -n "$DROP" ]; then
  REF=$(resolve_stash "$DROP") || exit 1
  git stash drop "$REF"
  echo "✅ Dropped $REF"
fi

if [ "$CLEAR" = "1" ]; then
  [ "$FORCE" != "1" ] && { echo "ERROR: --clear requires --force"; exit 1; }
  git stash clear
  echo "✅ All stashes cleared"
fi
```

### Step 6 — Auto-stash-before-pull

A common workflow: dirty tree, want to pull, don't want to interleave the pull merge with WIP changes.

```bash
if [ "$AUTO_PULL" = "1" ]; then
  if git diff-index --quiet HEAD --; then
    echo "Working tree clean — pulling directly."
    git pull --rebase
    exit 0
  fi
  STAMP="auto-pull-$(date +%s)"
  echo "Stashing as: $STAMP"
  git stash push -m "$STAMP" --include-untracked || { echo "ERROR: stash failed"; exit 1; }
  if git pull --rebase; then
    echo "Pull successful. Restoring stash..."
    if git stash pop; then
      echo "✅ Stash restored cleanly."
    else
      echo "⚠️  Conflicts restoring stash. Resolve and run: git stash drop"
    fi
  else
    echo "ERROR: pull failed — your stash '$STAMP' is preserved at stash@{0}"
  fi
fi
```

Note `git pull` already supports `--autostash` natively (since 2.9). The skill's `--auto-pull` adds named stashes, rebase mode default, and clearer error reporting.

## Output Contract

```
## Stash Helper

**Action:**     list | preview | push | apply | pop | drop | clear | auto-pull
**Stash count:** <N>
**Affected:**   stash@{0}  (name "<name>") — <K> file(s), <relative-time>
**Result:**     applied cleanly | conflicts (resolve and drop) | dropped | created
**Recovery:**   git stash list  |  git fsck --no-reflogs --unreachable (orphaned stashes)
```

## Gotchas

- **`git stash pop` is NOT atomic.** If conflicts occur during apply, the entry remains in the stash list. Always check the exit code.
- **Untracked files are NOT stashed by default.** New files sit in the working tree, untouched by `git stash`. Pass `--include-untracked` (or `-u`) to capture them. `--all` also stashes ignored files (rarely wanted).
- **Named stashes:** there's no first-class "name" — the `-m` message is just the stash subject. Resolution by name is a grep against `git stash list` and ambiguous matches return the first hit.
- **`git stash clear` is silent and destructive.** Always gate behind `--force`. Recovery requires `git fsck --no-reflogs --unreachable` to find dangling stash commits, then manual `git stash store`.
- **Stash on detached HEAD:** works, but the stash records the parent commit, not a branch. Applying later requires checking out that commit first or accepting the apply on a different branch (which may conflict).
- **Worktrees share the stash list with the main repo.** A stash created in worktree A is visible from worktree B — but applying in B against a different branch is a frequent source of conflicts.
- **`git stash apply` vs `pop`:** apply keeps the entry; pop removes it. Default to `apply` for safety; users opt in to `pop`.

## Cross-Platform Notes

- All `git stash` subcommands are stable since git 2.13 (with `push` semantics). macOS ships git 2.39+, Linux distros 2.20+, Windows Git for Windows 2.40+.
- The `--include-untracked` flag is identical across platforms.
- On Windows, the `stash@{N}` syntax requires escaping `{` and `}` in CMD; PowerShell and Git Bash handle it transparently. Quote the whole ref: `"stash@{0}"`.
