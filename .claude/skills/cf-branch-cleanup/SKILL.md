---
name: cf-branch-cleanup
category: coding
description: When the user asks to clean up branches, remove merged branches, prune stale remotes, organize branch structure, or delete old branches — activate this branch cleanup skill
---

# Branch Cleanup — Git Branch Hygiene Utility

Comprehensive branch cleanup across local and remote repositories. Unlike worktree-cleanup (which targets worktree-specific branches), this handles ALL branches: merged, squash-merged, stale, and orphaned.

## Activation

- User says "clean up branches", "delete merged branches", "prune stale remotes"
- User says "too many branches", "branch hygiene", "remove old branches"
- User passes flags: `--dry-run`, `--local-only`, `--remote-only`, `--force`

## Process

### 1. Survey Current State

```bash
echo "=== Local branches ==="
git branch --list | wc -l
echo "=== Remote branches ==="
git branch -r | wc -l
echo "=== Merged into main ==="
git branch --merged main 2>/dev/null | grep -v '^\*\|main\|master' | wc -l
echo "=== Recent branches (last 10) ==="
git for-each-ref --count=10 --sort=-committerdate refs/heads/ --format='%(refname:short) — %(committerdate:relative)'
echo "=== Stale branches (>30 days, no activity) ==="
git for-each-ref --sort=committerdate refs/heads/ --format='%(refname:short) %(committerdate:relative)' | grep -E '(months?|year) ago'
```

Always run `git fetch --prune` first to sync remote state before any analysis.

### 2. Identify Candidates

Categorize every branch into one of four buckets:

| Category | Detection Method | Default Action |
|----------|-----------------|----------------|
| **Safe to delete** | `git branch --merged main` | Auto-delete |
| **Likely safe** | Squash-merged: `git diff main...<branch> --stat` returns empty | Delete with note |
| **Stale** | No commits in 30+ days, not merged | Flag for review |
| **Protected** | main, master, develop, release/* | Never delete |

For squash-merge detection, an empty diff against main means the branch content was already incorporated even though git does not consider it "merged."

### 3. Check for Open PRs

Before recommending deletion of any branch, check for open pull requests:

```bash
gh pr list --head "$BRANCH" --state open --json number,title --jq '.[0].number // empty'
```

Branches with open PRs should be flagged and excluded from auto-deletion. Inform the user which branches have active PRs.

### 4. Present Plan

Show a table of all branches with recommended actions:

```
Branch Cleanup Plan
===================

| # | Branch                     | Status         | Age          | Action        |
|---|----------------------------|----------------|--------------|---------------|
| 1 | feature/old-login          | Merged         | 3 months ago | Will delete   |
| 2 | jane/add-retry             | Squash-merged  | 2 weeks ago  | Will delete   |
| 3 | experiment/perf-test       | Stale          | 4 months ago | Flag (review) |
| 4 | main                       | Protected      | -            | Skip          |
| 5 | dave/wip-refactor          | Open PR #42    | 1 week ago   | Skip (has PR) |
```

Ask user for confirmation before executing. In `--dry-run` mode, display the table and stop.

### 5. Execute Cleanup

Support these modes via flags:

| Flag | Behavior |
|------|----------|
| *(no flag)* | Interactive — confirm each batch before deletion |
| `--dry-run` | Show plan only, make no changes |
| `--local-only` | Delete local branches only, skip remote |
| `--remote-only` | Prune remote-tracking refs and delete remote branches only |
| `--force` | Include stale unmerged branches (with per-branch confirmation) |

Local deletion:
```bash
git branch -d "$BRANCH"          # safe delete (fails if unmerged)
git branch -D "$BRANCH"          # force delete (only with --force + confirmation)
```

Remote deletion:
```bash
git fetch --prune
git push origin --delete "$BRANCH" 2>/dev/null
```

### 6. Summary

```
Cleanup Complete
================

  Deleted local:    5 branches
  Deleted remote:   3 branches
  Skipped:          2 (1 unmerged, 1 has open PR)
  Protected:        3 (main, master, develop)

Before: 14 local / 22 remote
After:  9 local / 19 remote
```

## Output

- Before/after branch counts (local and remote)
- List of deleted branches with reason (merged, squash-merged, stale)
- List of skipped branches with reason (unmerged, open PR, protected)
- Any errors encountered during remote deletion

## Gotchas

- **Never delete protected branches**: main, master, develop, release/* are always protected — even if technically "merged" into each other.
- **Squash-merge false positives**: `git diff main...<branch> --stat` returning empty can also happen on manually rebased branches that were abandoned. The open-PR check helps catch these.
- **Remote deletion is silent on failure**: `git push origin --delete` fails silently if the branch was already deleted (e.g., GitHub auto-delete on merge). Suppress errors with `2>/dev/null` but log the attempt.
- **Always fetch before analysis**: Run `git fetch --prune` before any branch inspection. Without it, remote-tracking refs may be stale and the survey will be inaccurate.
- **Open PR check requires `gh` CLI**: If `gh` is not available, skip the PR check and warn the user that branches with open PRs may be included in deletion candidates.
- **Branch `-d` vs `-D`**: Use `-d` (safe delete) by default. Only use `-D` (force) when the user explicitly passes `--force` and confirms per branch.
- **Large repos with hundreds of branches**: The survey commands may be slow. Consider limiting output with `--count` flags and processing in batches.
