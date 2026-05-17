---
name: cf-tools-code-find-todo
description: "Find all TODO comments across a codebase, annotated with git-blame author. Trigger: /cf-tools-code-find-todo"
trigger: /cf-tools-code-find-todo
version: 1.0.0
---

# /cf-tools-code-find-todo

Scan a repo for `TODO` markers and render a table with file, line, author (via `git blame`), and message. Prefers `ripgrep` for speed; falls back to `grep -rn`.

## Usage

```
/cf-tools-code-find-todo                            # current dir
/cf-tools-code-find-todo /path/to/repo
/cf-tools-code-find-todo /path/to/repo --no-blame   # skip author lookup
/cf-tools-code-find-todo /path/to/repo --json
```

Arguments:
1. `path` (optional, default `.`) — directory to scan
2. `--no-blame` — skip git-blame author column (much faster)
3. `--json` — emit JSON array instead of table

## What You Must Do When Invoked

### Step 1 — Pick a search tool

```bash
TARGET="${1:-.}"
[ -d "$TARGET" ] || { echo "ERROR: not a directory: $TARGET"; exit 1; }

# Restrict to common source extensions to avoid noise from data files
SRC_EXTS='ts,tsx,js,jsx,py,go,rs,java,kt,swift,c,cc,cpp,h,hpp,cs,php,rb,sh,bash,zsh,sql,html,css,scss,vue,svelte'

if command -v rg >/dev/null 2>&1; then
  rg -n --no-heading --color=never \
     --type-add "src:*.{${SRC_EXTS}}" --type src \
     'TODO' "$TARGET" > /tmp/cf-todo-raw.txt
else
  echo "[note] ripgrep not found, falling back to grep -rn (slower)"
  # Build --include patterns from SRC_EXTS
  INCLUDES=$(echo "$SRC_EXTS" | tr ',' '\n' | sed 's/^/--include=*./' | tr '\n' ' ')
  eval "grep -rn $INCLUDES 'TODO' $TARGET" \
     --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist > /tmp/cf-todo-raw.txt 2>/dev/null
fi

COUNT=$(wc -l < /tmp/cf-todo-raw.txt | tr -d ' ')
echo "Found $COUNT TODO occurrences."
```

### Step 2 — Annotate with git blame (unless --no-blame)

```bash
python3 - "$TARGET" <<'PY'
import os, sys, subprocess, json

target = os.path.abspath(sys.argv[1])
no_blame = os.environ.get("NO_BLAME") == "1"
emit_json = os.environ.get("EMIT_JSON") == "1"

rows = []
with open('/tmp/cf-todo-raw.txt') as fh:
    for raw in fh:
        raw = raw.rstrip('\n')
        if not raw: continue
        # Format: path:line:content
        try:
            path, lineno, content = raw.split(':', 2)
        except ValueError:
            continue
        msg = content.strip()
        # Trim leading comment chars
        for tok in ['//', '#', '/*', '*', '--', '<!--']:
            if msg.startswith(tok):
                msg = msg[len(tok):].strip(); break
        author = ""
        if not no_blame:
            try:
                out = subprocess.check_output(
                    ['git', '-C', target, 'blame', '-L', f'{lineno},{lineno}',
                     '--porcelain', path],
                    stderr=subprocess.DEVNULL, text=True, timeout=3)
                for line in out.splitlines():
                    if line.startswith('author '):
                        author = line[7:].strip(); break
            except Exception:
                author = "—"
        rows.append({'path': path, 'line': int(lineno), 'author': author, 'message': msg})

if emit_json:
    print(json.dumps(rows, indent=2))
else:
    if not rows:
        print("(no TODOs found)")
        sys.exit(0)
    # Render table
    w_path = min(50, max(len(r['path']) for r in rows))
    w_auth = min(20, max(len(r['author']) for r in rows) or 1)
    print(f"{'File':<{w_path}} {'Line':>5} {'Author':<{w_auth}}  Message")
    print('-' * (w_path + w_auth + 30))
    for r in rows:
        msg = r['message'][:80] + ('…' if len(r['message']) > 80 else '')
        print(f"{r['path']:<{w_path}} {r['line']:>5} {r['author']:<{w_auth}}  {msg}")
PY
```

### Step 3 — Summary

```bash
echo ""
echo "Total TODOs: $COUNT"
```

## Output Contract

```
## TODO scan
**Target:**     <abs-path>
**Tool:**       rg | grep
**Found:**      <N>

File                            Line  Author          Message
src/api/auth.ts                   42  jane            refactor token validation
src/cli/commands.py              118  john            handle empty argv case
...
```

## Gotchas

- **Matches `TODO` inside strings/docstrings**: that's intentional — false positives are easy to ignore. To strip them you need an AST parser per language.
- **Git blame is slow on big repos**: blame is per-line via `subprocess`. For repos with 1000+ TODOs, use `--no-blame`.
- **Non-git directories**: blame silently fails, author column shows `—`. Don't error out.
- **Case-sensitive on purpose**: matches `TODO`, not `todo` or `Todo`. Adjust to `-i` if the user wants both.
- **Binary files**: ripgrep skips them by default. grep fallback may need `--binary-files=without-match` if it produces noise.
- **Excluded dirs in grep fallback**: only `node_modules`, `.git`, `dist`. Extend if the user has `vendor/`, `target/`, etc.

## Cross-Platform Notes

- **macOS**: `brew install ripgrep`
- **Linux**: `sudo apt install ripgrep` / `sudo dnf install ripgrep`
- **Windows**: `choco install ripgrep` or `scoop install ripgrep`. Inside WSL: apt.
- Falls back gracefully to `grep -rn` if `rg` is missing.
