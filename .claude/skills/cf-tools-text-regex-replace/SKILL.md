---
name: cf-tools-text-regex-replace
description: "In-place regex search/replace with backups, sed for single-line, perl for multiline. Trigger: /cf-tools-text-regex-replace"
trigger: /cf-tools-text-regex-replace
version: 1.0.0
---

# /cf-tools-text-regex-replace

Run a regex find/replace across one or more files. Uses `sed` for simple single-line patterns and `perl` for multiline / lookaround patterns. Always backs up to `<file>.bak` unless `--no-backup` is passed.

## Usage

```
/cf-tools-text-regex-replace file.txt 'foo' 'bar'
/cf-tools-text-regex-replace file.txt 'fo+' 'bar' --regex
/cf-tools-text-regex-replace file.md '(?s)<!--.*?-->' '' --multiline
/cf-tools-text-regex-replace 'src/**/*.js' 'console\.log\(.*\);' '' --regex --glob
/cf-tools-text-regex-replace file.txt 'foo' 'bar' --no-backup
```

Arguments:
1. `file-or-glob` (required) — target path or glob pattern (with `--glob`)
2. `pattern` (required) — search pattern (literal by default, regex with `--regex`)
3. `replacement` (required) — replacement string (`$1` for capture groups in perl mode)
4. `--regex` (optional) — treat pattern as extended regex
5. `--multiline` (optional) — use perl with `(?s)` semantics
6. `--no-backup` (optional) — skip `.bak` file
7. `--glob` (optional) — expand pattern as a glob and apply to each match

## Self-Contained Snippet

```bash
FILE="$1"; PAT="$2"; REPL="$3"
[ -f "$FILE" ] || { echo "ERROR: file not found"; exit 1; }
cp "$FILE" "${FILE}.bak"
# Single-line regex via perl (portable across BSD/GNU):
perl -i -pe "s/$PAT/$REPL/g" "$FILE"
echo "Replaced. Backup at ${FILE}.bak"
```

## What You Must Do When Invoked

### Step 1 — Validate

```bash
FILE="$1"; PAT="$2"; REPL="$3"
[ -n "$FILE" ] && [ -n "$PAT" ] || { echo "ERROR: file and pattern required"; exit 1; }
```

### Step 2 — Parse flags

```bash
REGEX=0; MULTI=0; NOBACKUP=0; GLOB=0
shift 3
while [ $# -gt 0 ]; do
  case "$1" in
    --regex) REGEX=1; shift;;
    --multiline) MULTI=1; REGEX=1; shift;;
    --no-backup) NOBACKUP=1; shift;;
    --glob) GLOB=1; shift;;
    *) shift;;
  esac
done
```

### Step 3 — Build file list

```bash
if [ "$GLOB" -eq 1 ]; then
  FILES=$(ls $FILE 2>/dev/null)
else
  FILES="$FILE"
fi
[ -n "$FILES" ] || { echo "ERROR: no files matched"; exit 1; }
```

### Step 4 — Apply replacement

```bash
for f in $FILES; do
  [ -f "$f" ] || continue
  [ "$NOBACKUP" -eq 0 ] && cp "$f" "${f}.bak"

  if [ "$MULTI" -eq 1 ]; then
    # Slurp whole file; (?s) makes . match newlines
    perl -i -0pe "s/$PAT/$REPL/g" "$f"
  elif [ "$REGEX" -eq 1 ]; then
    perl -i -pe "s/$PAT/$REPL/g" "$f"
  else
    # Literal — escape regex metachars in pattern
    ESC_PAT=$(printf '%s' "$PAT" | perl -pe 's/([.\\\+\*\?\[\^\]\$\(\)\{\}\|\/])/\\$1/g')
    ESC_REPL=$(printf '%s' "$REPL" | perl -pe 's/([\\\/&])/\\$1/g')
    perl -i -pe "s/$ESC_PAT/$ESC_REPL/g" "$f"
  fi
  echo "✓ Replaced in $f"
done
```

## Output Contract

```
## Regex replace

Pattern:     <pattern>
Replacement: <replacement>
Mode:        literal | regex | multiline-regex
Files:       <count>
Backups:     <count or "skipped">

<per-file status lines>
```

## Gotchas

- **BSD vs GNU sed `-i`**: BSD sed (macOS) requires `-i ''` with an explicit empty extension; GNU sed accepts bare `-i`. **Use perl `-i` to avoid this trap.**
- **Special chars in pattern**: `/` `&` `$` `\` need escaping inside `s///`. The literal-mode branch above handles this; in `--regex` mode the user is responsible.
- **Backup pollution**: rerunning without `--no-backup` overwrites prior `.bak`. Add `.bak.$$` for timestamped backups if needed.
- **`--multiline` and shell quoting**: patterns with `\n` should be written as `\n` inside single-quoted args; perl interprets them at runtime.
- **Capture groups**: perl uses `$1`, `$2`, not `\1`. If user passes `\1`, convert it: `${REPL//\\1/\$1}`.
- **Don't run on binary files**: perl `-i` will corrupt them. Detect with `file "$f" | grep -q text` first.

## Cross-Platform Notes

- **macOS**: `sed -i ''` (requires empty string). `perl -i` works without the dance.
- **Linux GNU**: `sed -i` works directly. `perl -i` also works.
- **Windows / Git Bash**: perl ships with Git for Windows. Use it for cross-platform scripts.
- **Encoding**: perl assumes UTF-8 with `-CSD` flag. For non-UTF8 files use `--encoding`.
