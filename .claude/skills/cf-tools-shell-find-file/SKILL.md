---
name: cf-tools-shell-find-file
description: "Smart find wrapper that excludes node_modules/.git/dist by default. Trigger: /cf-tools-shell-find-file"
trigger: /cf-tools-shell-find-file
version: 1.0.0
---

# /cf-tools-shell-find-file

Find files quickly without drowning in `node_modules`, `.git`, `dist`, `build`, `.next`, `target`, `__pycache__`, `.venv`, or `.idea`. Sane defaults + a few common flags.

For really large repos, prefer `fd` (`brew install fd`) — but this skill works with plain `find` everywhere.

## Usage

```
/cf-tools-shell-find-file --name "*.ts"
/cf-tools-shell-find-file --name "Dockerfile*" --type f
/cf-tools-shell-find-file --name "test_*" --newer 1d --path src/
/cf-tools-shell-find-file --name "*.log" --type f --include-junk        # disable noise filter
```

Arguments:
1. `--name PATTERN` (required) — glob pattern (e.g. `*.ts`, `README.*`, `Dockerfile*`)
2. `--type f|d` (optional, default `f`) — file or directory
3. `--newer DURATION` (optional) — modified within last N seconds/minutes/hours/days (e.g. `1d`, `3h`, `30m`)
4. `--path PATH` (optional, default `.`) — root to search from
5. `--include-junk` (optional flag) — disable the noise-filter pruning

## What You Must Do When Invoked

### Step 1 — Validate args + resolve duration

```bash
NAME="<from --name>"
TYPE="${TYPE:-f}"
ROOT="${ROOT:-.}"
[ -z "$NAME" ] && { echo "ERROR: --name required"; exit 1; }
[ ! -d "$ROOT" ] && { echo "ERROR: --path not a directory: $ROOT"; exit 1; }

# Convert --newer 1d → -mtime -1 (days) / -mmin (minutes) / portable -newer ref
NEWER_FLAG=""
if [ -n "$NEWER" ]; then
  UNIT="${NEWER: -1}"
  N="${NEWER%?}"
  case "$UNIT" in
    s) MIN=$(awk "BEGIN {print $N/60}");  NEWER_FLAG="-mmin -$MIN" ;;
    m) NEWER_FLAG="-mmin -$N" ;;
    h) MIN=$((N * 60));                    NEWER_FLAG="-mmin -$MIN" ;;
    d) NEWER_FLAG="-mtime -$N" ;;
    *) echo "ERROR: --newer unit must be s/m/h/d"; exit 1 ;;
  esac
fi
```

### Step 2 — Build the prune list

```bash
PRUNE_DIRS=(node_modules .git dist build .next target __pycache__ .venv venv .idea .vscode .DS_Store .cache .pytest_cache .ruff_cache .mypy_cache coverage out)

if [ "$INCLUDE_JUNK" = "1" ]; then
  PRUNE_EXPR=""
else
  # ( -type d \( -name a -o -name b -o … \) -prune ) -o
  PRUNE_EXPR="( -type d ("
  first=1
  for d in "${PRUNE_DIRS[@]}"; do
    [ $first -eq 1 ] && first=0 || PRUNE_EXPR="$PRUNE_EXPR -o"
    PRUNE_EXPR="$PRUNE_EXPR -name $d"
  done
  PRUNE_EXPR="$PRUNE_EXPR ) -prune ) -o"
fi
```

### Step 3 — Run find

```bash
# Use eval so the assembled expression evaluates correctly
eval find "$ROOT" $PRUNE_EXPR \
  \( -type "$TYPE" -name "'$NAME'" $NEWER_FLAG -print \) \
  2>/dev/null
```

Wrap NAME in single quotes inside the eval so globs aren't expanded by the shell before find sees them.

### Step 4 — Report count + tip

```bash
COUNT=$(... pipe step 3 to wc -l ...)
```

If COUNT is 0, suggest disabling junk filter or broadening the pattern. If COUNT > 500, suggest narrowing.

## Output Contract

```
## File search results

**Pattern:**       <name>
**Type:**          file | directory
**Root:**          <path>
**Newer than:**    <duration | (any age)>
**Pruned:**        node_modules, .git, dist, build, .next, target, __pycache__, .venv, .idea
**Matches:**       <count>

<list of paths, one per line, up to 100. If more, say "... and <N> more.">
```

## Gotchas

- **Glob expansion**: `--name *.ts` (unquoted) is expanded by the shell first. The skill quotes for you, but if the user passes it on the command line, they must quote: `--name "*.ts"`.
- **Hidden files**: find walks them by default. Excluded dirs above include common hidden ones (`.git`, `.cache`, etc.) — but other dotfiles still appear.
- **Permission denied noise**: piped to `/dev/null` so the user sees results, not perms warnings. Add `--include-junk` and pipe stderr if you want them.
- **macOS `find` lacks `-printf`**: this skill avoids it for portability. Just `-print`.
- **Symlink loops**: find follows symlinks only with `-L`. The skill doesn't pass `-L`, so loops are safe.
- **`fd` is 10× faster**: if `command -v fd`, suggest `fd '<pattern>' <root>` — same defaults out of the box.

## Cross-Platform Notes

- **macOS / Linux / WSL**: GNU find on Linux supports more flags but the skill uses only POSIX-portable ones.
- **`-newermt`** (mtime ≥ date) is GNU-only; this skill uses `-mtime` / `-mmin` which both BSD and GNU support.
- **Windows native PowerShell**: use `Get-ChildItem -Recurse -Filter` instead.
