---
name: cf-tools-git-blame-search
description: "Find when a line, string, or regex was introduced — pickaxe search with author and commit info. Trigger: /cf-tools-git-blame-search"
trigger: /cf-tools-git-blame-search
version: 1.0.0
---

# /cf-tools-git-blame-search

Find the commit that introduced (or removed) a specific line, string, or regex pattern. Wraps `git log -S` (pickaxe) and `-G` (regex) with author, commit, and date enrichment. Falls back to `git blame` for line-by-line attribution when a file path is known.

## Usage

```
/cf-tools-git-blame-search "<exact-string>"                      # pickaxe -S (literal)
/cf-tools-git-blame-search -G '<regex>'                          # pickaxe -G (regex)
/cf-tools-git-blame-search "<string>" -- path/to/file.ts         # restrict to file/dir
/cf-tools-git-blame-search "<string>" --limit 10                 # top N hits
/cf-tools-git-blame-search --blame path/to/file.ts:42            # line-level blame
/cf-tools-git-blame-search --since "1 year ago" "<string>"       # time-bounded
```

## What You Must Do When Invoked

### Step 1 — Choose the right mode

| Input shape | Mode | Git command |
|-------------|------|-------------|
| Plain string `foo` | Pickaxe literal | `git log -S "foo"` |
| Regex flag `-G '^class\s+Foo'` | Pickaxe regex | `git log -G '...'` |
| `--blame path:line` | Line attribution | `git blame -L line,line path` |
| Path-restricted | Add `-- path` | `git log -S ... -- path/` |

`-S` matches when a change adds or removes the exact string — counts of the string before/after the commit must differ. `-G` matches when the regex matches any added/removed line. Use `-S` for symbol additions (function/class names), `-G` for structural patterns.

### Step 2 — Run pickaxe with enriched output

```bash
QUERY="$1"
MODE="${MODE:-S}"   # S or G
LIMIT="${LIMIT:-20}"
PATH_FILTER="${PATH_FILTER:-}"

echo "=== Searching commits where '$QUERY' was introduced/removed ==="
echo "    Mode: -${MODE}  Limit: ${LIMIT}  Path filter: ${PATH_FILTER:-<none>}"
echo ""

git log "-${MODE}" "$QUERY" \
  --pretty=format:'%C(yellow)%h%Creset %C(blue)%an%Creset %C(green)(%ar)%Creset %s' \
  --max-count="$LIMIT" \
  ${SINCE:+--since="$SINCE"} \
  ${UNTIL:+--until="$UNTIL"} \
  ${PATH_FILTER:+-- "$PATH_FILTER"}
```

### Step 3 — Show first hit in detail

The first commit returned by pickaxe (which walks history newest-first) is usually the **most recent** time the string was added or removed. To find the **original introduction**, append `--reverse` and re-show:

```bash
echo ""
echo "=== Earliest commit touching '$QUERY' ==="
FIRST=$(git log "-${MODE}" "$QUERY" --reverse --pretty=format:'%H' --max-count=1 ${PATH_FILTER:+-- "$PATH_FILTER"})
if [ -n "$FIRST" ]; then
  git show --stat "$FIRST" | head -30
  echo ""
  echo "Full patch: git show $FIRST"
fi
```

### Step 4 — Line-level blame mode

```bash
if [ -n "$BLAME_TARGET" ]; then
  # Parse path:line
  FILE="${BLAME_TARGET%%:*}"
  LINE="${BLAME_TARGET##*:}"
  if [ ! -f "$FILE" ]; then
    echo "ERROR: file not found: $FILE"; exit 1
  fi
  echo "=== Blame for $FILE:$LINE ==="
  git blame -L "${LINE},${LINE}" --show-email "$FILE"
  echo ""
  COMMIT=$(git blame -L "${LINE},${LINE}" --porcelain "$FILE" | head -1 | awk '{print $1}')
  echo "=== Commit that last touched this line ==="
  git show --stat "$COMMIT"
fi
```

### Step 5 — Render result table

```
| # | SHA      | Author          | When         | Subject                                 |
|---|----------|-----------------|--------------|-----------------------------------------|
| 1 | ee3b88e  | Jane Doe        | 3 weeks ago  | feat: add user-token parser             |
| 2 | f56af5d  | Bob Smith       | 5 months ago | refactor: rename auth-token to user-tok |
| 3 | aa34679  | Jane Doe        | 1 year ago   | feat: initial token implementation      |
```

Then expand the earliest hit (last row) showing the introduction patch.

## Output Contract

```
## Pickaxe / Blame Search

**Query:**       "<string>" or /<regex>/
**Mode:**        -S literal | -G regex | blame
**Path filter:** <path or none>
**Matches:**     <N> commits
**First seen:**  <abbrev>  <author>  <date>  <subject>
**Last touched:** <abbrev>  <author>  <date>  <subject>
**Patch:**       git show <abbrev>
```

## Gotchas

- **`-S` is whitespace-sensitive.** Searching for `foo (bar)` matches differently from `foo(bar)`. For loose matching use `-G` with a regex.
- **`-G` matches any line where the regex is added or removed**, even if the actual string occurrence count didn't change. `-S` is stricter — it matches when the count changes. Pick `-S` for "when was this symbol introduced", `-G` for "when did this pattern appear in a diff".
- **Pickaxe ignores merge commits** by default. Add `--full-history` to include them when needed, but expect more noise.
- **File renames break naive blame.** Use `git log --follow --pretty=oneline -- <path>` to trace through renames before pickaxe.
- **`--reverse` returns commits in chronological order**, so to find the *introduction* commit it must be combined with `--max-count=1` after `--reverse`.
- **Large repos:** pickaxe is O(history × diff-size). Always bound with `--since` or path filters on monorepos.
- **Special characters in query:** `$`, `` ` ``, `"` must be escaped or single-quoted. The skill should quote the query carefully when constructing the command.

## Cross-Platform Notes

- All flags are stable git-2.0+ features — identical on macOS, Linux, WSL, Windows Git Bash.
- The colored `--pretty=format:` uses `%C(...)` which renders ANSI escapes only when stdout is a TTY. Pipe-safe — no manual stripping needed.
- On Windows CMD without ANSI, the colors degrade gracefully to plain text.
