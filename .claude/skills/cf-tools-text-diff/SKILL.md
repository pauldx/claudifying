---
name: cf-tools-text-diff
description: "Unified diff between two files or two directories, colorized output, configurable context. Trigger: /cf-tools-text-diff"
trigger: /cf-tools-text-diff
version: 1.0.0
---

# /cf-tools-text-diff

Show a unified diff between two files or two directories. Defaults to 3 lines of context and color output when the terminal supports it. Falls back gracefully when `colordiff` isn't installed.

## Usage

```
/cf-tools-text-diff a.txt b.txt
/cf-tools-text-diff dir1/ dir2/
/cf-tools-text-diff a.txt b.txt --context 5
/cf-tools-text-diff dir1/ dir2/ --ignore-whitespace
```

Arguments:
1. `path-a` (required) — first file or directory
2. `path-b` (required) — second file or directory
3. `--context N` (optional, default `3`) — lines of context
4. `--ignore-whitespace` (optional) — pass `-w` to diff
5. `--brief` (optional) — only report which files differ (`-q`)

## Self-Contained Snippet

```bash
A="$1"; B="$2"; CTX="${3:-3}"
[ -e "$A" ] && [ -e "$B" ] || { echo "ERROR: both paths must exist"; exit 1; }
if [ -d "$A" ] && [ -d "$B" ]; then
  diff -ruN -U "$CTX" "$A" "$B" | { command -v colordiff >/dev/null && colordiff || cat; }
else
  diff -u -U "$CTX" "$A" "$B" | { command -v colordiff >/dev/null && colordiff || cat; }
fi
```

## What You Must Do When Invoked

### Step 1 — Validate inputs

```bash
A="$1"; B="$2"
[ -e "$A" ] || { echo "ERROR: path not found: $A"; exit 1; }
[ -e "$B" ] || { echo "ERROR: path not found: $B"; exit 1; }
```

### Step 2 — Parse flags

```bash
CTX=3
EXTRA=""
shift 2
while [ $# -gt 0 ]; do
  case "$1" in
    --context) CTX="$2"; shift 2;;
    --ignore-whitespace) EXTRA="$EXTRA -w"; shift;;
    --brief) EXTRA="$EXTRA -q"; shift;;
    *) shift;;
  esac
done
```

### Step 3 — Dispatch file vs directory

```bash
if [ -d "$A" ] && [ -d "$B" ]; then
  diff -ruN -U "$CTX" $EXTRA "$A" "$B" | { command -v colordiff >/dev/null && colordiff || cat; }
elif [ -f "$A" ] && [ -f "$B" ]; then
  diff -u -U "$CTX" $EXTRA "$A" "$B" | { command -v colordiff >/dev/null && colordiff || cat; }
else
  echo "ERROR: mixed file/directory comparison not supported"; exit 1
fi
```

Exit codes from `diff`:
- `0` — files identical
- `1` — files differ
- `2` — trouble (invalid input, missing file)

Report the exit code so the caller knows whether differences were found.

## Output Contract

```
## Diff: <path-a> vs <path-b>

Context lines: <N>
Mode:          file | directory
Differences:   <yes|no>

<unified diff body>
```

If `--brief`, list only changed files (one per line).

## Gotchas

- **`diff` vs `colordiff`**: macOS doesn't ship `colordiff`. Install via `brew install colordiff` for color. Fallback is plain `diff`.
- **Binary files**: `diff` will say `Binary files X and Y differ`. Use `--text` to force comparison, or `xxd a.bin | diff - <(xxd b.bin)` for a byte-level diff.
- **Trailing newline differences**: BSD `diff` may emit `\ No newline at end of file`. This is informational, not a bug.
- **Large directories**: `-r` recurses without limit. Pipe through `head -200` if output overwhelms.
- **CRLF vs LF**: Windows line endings cause every line to "differ". Run files through `dos2unix` first, or use `--strip-trailing-cr`.

## Cross-Platform Notes

- **macOS / BSD diff**: supports `-U`, `-u`, `-r`, `-q`, `-w`, `-N`. No `--color` flag — use external `colordiff`.
- **Linux / GNU diff**: supports `--color=auto` natively (since v3.4). Prefer it when available:
  ```bash
  diff --color=auto -u "$A" "$B" 2>/dev/null || diff -u "$A" "$B"
  ```
- **Windows**: use Git Bash `diff` or WSL. PowerShell `Compare-Object` is line-oriented but not unified format.
