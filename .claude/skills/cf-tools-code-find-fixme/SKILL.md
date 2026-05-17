---
name: cf-tools-code-find-fixme
description: "Find FIXME / HACK / XXX comments across a codebase with git-blame author. Trigger: /cf-tools-code-find-fixme"
trigger: /cf-tools-code-find-fixme
version: 1.0.0
---

# /cf-tools-code-find-fixme

Like `cf-tools-code-find-todo` but for higher-priority markers: `FIXME`, `HACK`, `XXX`. These typically indicate known broken code, ugly workarounds, or warnings about subtle bugs. Output groups results by marker type.

## Usage

```
/cf-tools-code-find-fixme                              # current dir
/cf-tools-code-find-fixme /path/to/repo
/cf-tools-code-find-fixme /path/to/repo --no-blame
/cf-tools-code-find-fixme /path/to/repo --only FIXME   # restrict marker
/cf-tools-code-find-fixme /path/to/repo --json
```

Arguments:
1. `path` (optional, default `.`) — directory to scan
2. `--no-blame` — skip git-blame author column
3. `--only <marker>` — restrict to one of FIXME, HACK, XXX (default: all three)
4. `--json` — JSON output

## What You Must Do When Invoked

### Step 1 — Build pattern

```bash
TARGET="${1:-.}"
ONLY="${ONLY:-}"   # e.g. "FIXME"

if [ -n "$ONLY" ]; then
  PATTERN="$ONLY"
else
  PATTERN='FIXME|HACK|XXX'
fi

SRC_EXTS='ts,tsx,js,jsx,py,go,rs,java,kt,swift,c,cc,cpp,h,hpp,cs,php,rb,sh,bash,zsh,sql,html,css,scss,vue,svelte'
```

### Step 2 — Search

```bash
if command -v rg >/dev/null 2>&1; then
  rg -n --no-heading --color=never \
     --type-add "src:*.{${SRC_EXTS}}" --type src \
     -e "$PATTERN" "$TARGET" > /tmp/cf-fixme-raw.txt
else
  # grep needs ERE -E plus include
  INCLUDES=$(echo "$SRC_EXTS" | tr ',' '\n' | sed 's/^/--include=*./' | tr '\n' ' ')
  eval "grep -rnE $INCLUDES '$PATTERN' $TARGET" \
     --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist > /tmp/cf-fixme-raw.txt 2>/dev/null
fi

COUNT=$(wc -l < /tmp/cf-fixme-raw.txt | tr -d ' ')
echo "Found $COUNT marker(s)."
```

### Step 3 — Classify & blame

```bash
python3 - "$TARGET" <<'PY'
import os, sys, subprocess, re, json, collections

target = os.path.abspath(sys.argv[1])
no_blame = os.environ.get("NO_BLAME") == "1"
emit_json = os.environ.get("EMIT_JSON") == "1"

MARKERS = ('FIXME', 'HACK', 'XXX')
buckets = collections.defaultdict(list)

with open('/tmp/cf-fixme-raw.txt') as fh:
    for raw in fh:
        raw = raw.rstrip('\n')
        if not raw: continue
        try:
            path, lineno, content = raw.split(':', 2)
        except ValueError:
            continue
        m = re.search(r'(FIXME|HACK|XXX)', content)
        if not m: continue
        marker = m.group(1)
        msg = content[m.end():].lstrip(': ').strip()
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
        buckets[marker].append({'path':path, 'line':int(lineno), 'author':author, 'message':msg})

if emit_json:
    print(json.dumps(buckets, indent=2))
else:
    if not any(buckets.values()):
        print("(no FIXME/HACK/XXX found)")
        sys.exit(0)
    for marker in MARKERS:
        rows = buckets.get(marker, [])
        if not rows: continue
        print(f"\n## {marker}  ({len(rows)})\n")
        w_path = min(50, max(len(r['path']) for r in rows))
        w_auth = min(20, max(len(r['author']) for r in rows) or 1)
        print(f"{'File':<{w_path}} {'Line':>5} {'Author':<{w_auth}}  Message")
        print('-' * (w_path + w_auth + 30))
        for r in rows:
            msg = r['message'][:80] + ('…' if len(r['message']) > 80 else '')
            print(f"{r['path']:<{w_path}} {r['line']:>5} {r['author']:<{w_auth}}  {msg}")
PY
```

## Output Contract

```
## FIXME / HACK / XXX scan
**Target:**     <abs-path>
**Tool:**       rg | grep
**Markers:**    FIXME, HACK, XXX

## FIXME  (12)
src/api/auth.ts        42  jane     token logic is wrong
...

## HACK   (5)
...

## XXX    (2)
...

**Totals:**  FIXME=12, HACK=5, XXX=2
```

## Gotchas

- **Don't merge with TODO scan**: TODOs are wishlist; FIXME/HACK/XXX are warnings. Keep them separate so they get triaged differently.
- **Marker false-positives in strings**: e.g. `"XXX"` placeholder in test fixtures. Acceptable noise — AST-aware filtering is out of scope.
- **Author=—**: file is in a non-git dir or git blame errored. Don't crash.
- **`HACK:` vs `HACK `**: pattern matches the word at any position. If your codebase has `HACKERMODE = true`, you'll get false matches. Tighten the regex to `\b(FIXME|HACK|XXX)\b` in ripgrep with `-w` if needed.
- **Performance**: 3 patterns × big repos × blame can be slow. Use `--no-blame` first, drill into specific markers with `--only`.

## Cross-Platform Notes

- Same as `cf-tools-code-find-todo`: prefer `ripgrep`, fall back to `grep -rnE`.
- macOS BSD grep supports `-E`; no syntax differences here.
