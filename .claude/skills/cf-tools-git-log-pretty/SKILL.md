---
name: cf-tools-git-log-pretty
description: "Opinionated git log graph with colors, refs, authors, and dates. Trigger: /cf-tools-git-log-pretty"
trigger: /cf-tools-git-log-pretty
version: 1.0.0
---

# /cf-tools-git-log-pretty

A single command that emits a beautifully formatted commit graph. Wraps `git log --graph --decorate --pretty` with sane defaults plus filters for max-count, branch, author, and date range.

## Usage

```
/cf-tools-git-log-pretty                      # last 20 commits on current branch
/cf-tools-git-log-pretty -n 50                # last 50
/cf-tools-git-log-pretty --all                # include all branches
/cf-tools-git-log-pretty --author "jane"      # filter by author
/cf-tools-git-log-pretty --since "1 week ago"
/cf-tools-git-log-pretty --grep "fix"         # filter by commit message regex
/cf-tools-git-log-pretty --branch main        # only show <branch>
/cf-tools-git-log-pretty --me                 # filter to git user.email
/cf-tools-git-log-pretty --files              # include file change list per commit
/cf-tools-git-log-pretty --stat               # include numstat per commit
```

## What You Must Do When Invoked

### Step 1 — Build the pretty format string

```bash
# Components, each on a separate %C(...)%Creset for portability:
#   %h        — abbrev sha (yellow)
#   %d        — refs decoration (red)
#   %s        — subject (default white)
#   %an       — author name (blue)
#   %ar       — author date relative (green)
#   %G?       — signature trust (only shown if signed)
FORMAT='%C(yellow)%h%Creset%C(red)%d%Creset %s %C(blue)<%an>%Creset %C(green)(%ar)%Creset'
```

### Step 2 — Build the argv

```bash
N="${COUNT:-20}"
ARGS=( log --graph --decorate --abbrev-commit --pretty=format:"$FORMAT" --max-count="$N" )

[ "$ALL" = "1" ]      && ARGS+=( --all )
[ -n "$AUTHOR" ]      && ARGS+=( --author="$AUTHOR" )
[ -n "$SINCE" ]       && ARGS+=( --since="$SINCE" )
[ -n "$UNTIL" ]       && ARGS+=( --until="$UNTIL" )
[ -n "$GREP" ]        && ARGS+=( --grep="$GREP" --regexp-ignore-case )
[ "$FILES" = "1" ]    && ARGS+=( --name-status )
[ "$STAT" = "1" ]     && ARGS+=( --stat )
[ -n "$BRANCH" ]      && ARGS+=( "$BRANCH" )

if [ "$ME" = "1" ]; then
  EMAIL=$(git config user.email)
  ARGS+=( --author="$EMAIL" )
fi
```

### Step 3 — Run with pager-aware output

```bash
# If stdout is a TTY, pipe through less -R to preserve colors; otherwise raw.
if [ -t 1 ]; then
  git "${ARGS[@]}" | less -RFX
else
  git "${ARGS[@]}"
fi
```

### Step 4 — Summary footer

```bash
echo ""
echo "=== Summary ==="
TOTAL=$(git "${ARGS[@]/--graph/}" --pretty=oneline | wc -l | tr -d ' ')
echo "  Commits matched: $TOTAL"
echo "  Branch:          $(git symbolic-ref --short HEAD 2>/dev/null || echo DETACHED)"
echo "  Up-to-date with: $(git rev-parse --abbrev-ref @{u} 2>/dev/null || echo '<no upstream>')"
```

## Output Contract

The actual log output uses ANSI colors and graph characters:

```
*   ee3b88e (HEAD -> main, origin/main) feat: add user-token parser <Jane Doe> (3 days ago)
|\
| * f56a... fix: token regex in legacy parser <Bob Smith> (4 days ago)
* | aa34... refactor: extract token validator <Jane Doe> (5 days ago)
|/
* 985f... feat: initial token implementation <Jane Doe> (2 weeks ago)
```

Followed by a summary block:

```
=== Summary ===
  Commits matched: 20
  Branch:          main
  Up-to-date with: origin/main
```

## Gotchas

- **`--graph` requires `--decorate` to look good** — decoration draws the (HEAD -> main, origin/main) refs at each node. Always pair them.
- **`--all` can be overwhelming on large repos.** With hundreds of branches the graph becomes spaghetti. Default to current-branch only; users opt in to `--all`.
- **Pager handling:** `git log` invokes `$PAGER` (usually `less -FRX`) for interactive use. When piping to a script, set `--no-pager` or use the TTY guard shown above.
- **Date formats:** `%ar` is relative ("3 days ago"). For precise diffs, use `%ai` (ISO 8601). For audit logs, prefer ISO.
- **Author filtering matches BOTH name and email.** `git log --author="jane"` matches "Jane Doe" and "jane@example.com" — usually what you want.
- **`--grep` regex defaults to case-sensitive.** Add `--regexp-ignore-case` (or `-i`) for case-insensitive search.
- **Merge commits show two parents in `%P`.** The graph handles this automatically; `--first-parent` hides side branches if user wants a linear view of mainline.
- **Empty repo:** `git log` errors. Pre-check with `git rev-parse HEAD 2>/dev/null` and report "No commits yet" cleanly.

## Cross-Platform Notes

- ANSI color escapes (`%C(yellow)`) render in modern terminals on macOS, Linux, WSL, Windows Terminal, Git Bash.
- Old Windows CMD without VT100 support strips them — colors degrade to plain text.
- The `less -RFX` flags: `-R` raw control chars (colors), `-F` quit if one screen, `-X` no init/deinit (preserves output on quit). Identical on all platforms.
