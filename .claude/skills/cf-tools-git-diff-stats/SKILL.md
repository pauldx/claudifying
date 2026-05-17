---
name: cf-tools-git-diff-stats
description: "File-change stats since a ref — highlights large changes over 100 LOC. Trigger: /cf-tools-git-diff-stats"
trigger: /cf-tools-git-diff-stats
version: 1.0.0
---

# /cf-tools-git-diff-stats

Compute per-file change statistics from a reference (branch, tag, or sha) to HEAD. Highlights large files (>100 LOC changed by default) and groups by extension. Useful for PR sizing, release notes prep, and refactor review.

## Usage

```
/cf-tools-git-diff-stats                       # diff vs origin/main (or main)
/cf-tools-git-diff-stats main                  # diff vs main
/cf-tools-git-diff-stats HEAD~5                # last 5 commits
/cf-tools-git-diff-stats v1.2.0 v1.3.0         # between two refs
/cf-tools-git-diff-stats --staged              # staged changes only
/cf-tools-git-diff-stats --unstaged            # working tree vs index
/cf-tools-git-diff-stats main --threshold 200  # flag files >200 LOC changed
/cf-tools-git-diff-stats main --by-ext         # group totals by extension
/cf-tools-git-diff-stats main --exclude '*.lock,*.min.js,dist/*'
```

## What You Must Do When Invoked

### Step 1 — Resolve refs

```bash
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: not a git repo"; exit 1; }

# Default base: origin/main, fallback to main, then master
BASE="${1:-}"
if [ -z "$BASE" ]; then
  for candidate in origin/main main origin/master master; do
    if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
      BASE="$candidate"
      break
    fi
  done
fi

HEAD_REF="${2:-HEAD}"

echo "Diffing: $BASE ... $HEAD_REF"
```

### Step 2 — Get numstat

```bash
THRESHOLD="${THRESHOLD:-100}"
EXCLUDE_GLOBS="${EXCLUDE:-}"

# numstat gives <added> <deleted> <path> per file
NUMSTAT=$(git diff --numstat ${EXCLUDE_GLOBS:+":(exclude)$EXCLUDE_GLOBS"} "$BASE...$HEAD_REF")

if [ -z "$NUMSTAT" ]; then
  echo "No changes between $BASE and $HEAD_REF."
  exit 0
fi
```

### Step 3 — Render top-line summary

```bash
echo ""
echo "=== Summary ==="
git diff --shortstat "$BASE...$HEAD_REF"
# Example output: 12 files changed, 487 insertions(+), 213 deletions(-)
```

### Step 4 — Per-file table with bars

```bash
echo ""
echo "=== Files changed (sorted by total LOC) ==="
printf '%s\n' "$NUMSTAT" \
  | awk -v thresh="$THRESHOLD" '
      {
        added=$1; deleted=$2; path=$0; sub(/^[0-9-]+\t[0-9-]+\t/, "", path);
        total = added + deleted;
        flag = (total >= thresh) ? "⚠️  LARGE" : "        ";
        printf "%s  +%-5d -%-5d  =%-5d  %s\n", flag, added, deleted, total, path;
      }
    ' \
  | sort -k4 -t'=' -nr \
  | head -50
```

For binary files, `git diff --numstat` outputs `-` instead of numeric counts. Show them as `[binary]` and skip threshold checks.

### Step 5 — Optional grouping by extension

```bash
if [ "$BY_EXT" = "1" ]; then
  echo ""
  echo "=== Totals by extension ==="
  printf '%s\n' "$NUMSTAT" \
    | awk '
        { added=$1; deleted=$2; path=$0; sub(/^[0-9-]+\t[0-9-]+\t/, "", path);
          n=split(path, parts, "."); ext=(n>1) ? parts[n] : "<no-ext>";
          a[ext]+=added; d[ext]+=deleted; f[ext]++;
        }
        END {
          for (e in a) printf "%-12s  files=%-4d  +%-6d -%-6d  =%d\n", e, f[e], a[e], d[e], a[e]+d[e];
        }
      ' \
    | sort -k5 -nr
fi
```

### Step 6 — Highlight callouts

```bash
echo ""
echo "=== Callouts ==="

# Files with deletions but no additions (deleted/moved candidates)
DELETED_ONLY=$(printf '%s\n' "$NUMSTAT" | awk '$1==0 && $2>0 {print "  DEL  "$3}')
[ -n "$DELETED_ONLY" ] && { echo "Files with only deletions:"; echo "$DELETED_ONLY"; }

# Files with churn (added AND deleted lines, both high)
HIGH_CHURN=$(printf '%s\n' "$NUMSTAT" | awk '$1>=50 && $2>=50 {print "  CHURN "$1"+ "$2"-  "$3}')
[ -n "$HIGH_CHURN" ] && { echo "High-churn files (50+ adds AND 50+ deletes):"; echo "$HIGH_CHURN"; }

# Large refactor (>500 LOC single file)
HUGE=$(printf '%s\n' "$NUMSTAT" | awk '($1+$2)>=500 {print "  HUGE  +"$1" -"$2"  "$3}')
[ -n "$HUGE" ] && { echo "Files over 500 LOC changed:"; echo "$HUGE"; }
```

## Output Contract

```
## Diff Stats — main ... feature/x

**Range:**       <base-ref> ... <head-ref>
**Summary:**     12 files changed, 487 insertions(+), 213 deletions(-)
**Threshold:**   100 LOC (override with --threshold)

### Files changed
⚠️  LARGE  +203  -45    =248  src/auth/token.ts
          +18   -12    =30   src/auth/index.ts
          +4    -1     =5    README.md
[binary]                     assets/logo.png

### Callouts
- Files with only deletions: <list>
- High-churn files: <list>
- Files over 500 LOC: <list>
```

## Gotchas

- **`A...B` (three dots) vs `A..B` (two dots).** `A...B` shows changes from the merge-base of A and B up to B — the right semantic for "what's in this PR vs main". `A..B` shows commits reachable from B but not from A (different! more useful for `git log`, less for `git diff`).
- **Binary files show `-` in numstat.** Awk-handle them or they break sorts.
- **Renames count as deletes+adds in `--numstat`.** Use `git diff -M --numstat` to detect renames and report them as a single move with similarity %.
- **Generated files inflate LOC.** Default-exclude common noise: `*.lock`, `*.min.js`, `*.min.css`, `dist/*`, `node_modules/*`, `vendor/*`. The `--exclude` flag uses git pathspec `:(exclude)` syntax.
- **Working tree dirty state:** `--unstaged` and `--staged` use different invocations (`git diff` vs `git diff --cached`). Mixing them with a base ref is undefined — refuse the combination.
- **No upstream / no main branch:** the auto-base fallback chain (`origin/main → main → origin/master → master`) handles most cases but fails for fresh repos. Surface a clear error: "no base ref found, pass one explicitly".

## Cross-Platform Notes

- `awk` is POSIX — works identically on macOS (BSD awk), Linux (gawk), and Git Bash. The script above avoids gawk-only features.
- `sort -k4 -t'=' -nr` works in BSD sort and GNU sort the same way.
- On Windows CMD, the `:(exclude)` pathspec must be quoted with double quotes; Git Bash and PowerShell can use single quotes.
