---
name: cf-tools-code-count-loc
description: "Count lines of code per language using tokei if installed, else a find+wc heuristic. Trigger: /cf-tools-code-count-loc"
trigger: /cf-tools-code-count-loc
version: 1.0.0
---

# /cf-tools-code-count-loc

Report LOC per language for a directory. Prefers `tokei` (fast, accurate, handles comments/blanks) and falls back to a portable `find` + `wc` heuristic when tokei is unavailable.

## Usage

```
/cf-tools-code-count-loc                        # current dir
/cf-tools-code-count-loc /path/to/repo
/cf-tools-code-count-loc /path/to/repo --json
/cf-tools-code-count-loc /path/to/repo --exclude node_modules,dist
```

Arguments:
1. `path` (optional, default `.`) — directory to scan
2. `--json` — emit JSON instead of table (tokei native)
3. `--exclude <csv>` — comma-separated dir names to skip (default: `node_modules,.git,dist,build,target,.venv,__pycache__`)

## What You Must Do When Invoked

### Step 1 — Prefer tokei

```bash
TARGET="${1:-.}"
[ -d "$TARGET" ] || { echo "ERROR: not a directory: $TARGET"; exit 1; }

if command -v tokei >/dev/null 2>&1; then
  if [ "$JSON" = "1" ]; then
    tokei --output json "$TARGET"
  else
    tokei "$TARGET"
  fi
  exit 0
fi
```

### Step 2 — Fallback: find + wc heuristic

```bash
EXCLUDE="${EXCLUDE:-node_modules,.git,dist,build,target,.venv,__pycache__}"

# Map extensions -> language name
python3 - "$TARGET" "$EXCLUDE" <<'PY'
import os, sys, collections, subprocess

target = sys.argv[1]
exclude = set(sys.argv[2].split(','))

EXT_LANG = {
 '.py':'Python', '.js':'JavaScript', '.ts':'TypeScript', '.tsx':'TypeScript',
 '.jsx':'JavaScript', '.go':'Go', '.rs':'Rust', '.rb':'Ruby', '.java':'Java',
 '.kt':'Kotlin', '.swift':'Swift', '.c':'C', '.h':'C/C++ Header',
 '.cpp':'C++', '.cc':'C++', '.cs':'C#', '.php':'PHP', '.sh':'Shell',
 '.bash':'Shell', '.zsh':'Shell', '.html':'HTML', '.css':'CSS',
 '.scss':'SCSS', '.md':'Markdown', '.yaml':'YAML', '.yml':'YAML',
 '.json':'JSON', '.toml':'TOML', '.sql':'SQL', '.r':'R', '.lua':'Lua',
 '.scala':'Scala', '.dart':'Dart', '.elm':'Elm', '.ex':'Elixir', '.exs':'Elixir',
 '.vue':'Vue', '.svelte':'Svelte',
}

stats = collections.defaultdict(lambda: {'files':0, 'lines':0, 'bytes':0})

for root, dirs, files in os.walk(target):
    dirs[:] = [d for d in dirs if d not in exclude]
    for f in files:
        _, ext = os.path.splitext(f)
        lang = EXT_LANG.get(ext.lower())
        if not lang: continue
        path = os.path.join(root, f)
        try:
            with open(path, 'rb') as fh:
                data = fh.read()
            stats[lang]['files'] += 1
            stats[lang]['lines'] += data.count(b'\n') + (1 if data and not data.endswith(b'\n') else 0)
            stats[lang]['bytes'] += len(data)
        except Exception:
            continue

rows = sorted(stats.items(), key=lambda kv: -kv[1]['lines'])
print(f"{'Language':<18} {'Files':>8} {'Lines':>10} {'Bytes':>12}")
print('-' * 52)
total_f = total_l = total_b = 0
for lang, s in rows:
    print(f"{lang:<18} {s['files']:>8} {s['lines']:>10} {s['bytes']:>12}")
    total_f += s['files']; total_l += s['lines']; total_b += s['bytes']
print('-' * 52)
print(f"{'TOTAL':<18} {total_f:>8} {total_l:>10} {total_b:>12}")
print()
print("[note] heuristic mode — counts ALL lines incl. blanks/comments. Install tokei for accurate split.")
PY
```

### Step 3 — Report

```bash
echo ""
echo "Method: $(command -v tokei >/dev/null 2>&1 && echo 'tokei' || echo 'find+wc heuristic')"
```

## Output Contract

```
## Lines of code
**Target:**   <abs-path>
**Method:**   tokei | heuristic
**Excluded:** node_modules, .git, dist, …

Language          Files     Lines       Bytes
---------------------------------------------
Python              42      8,341     245,011
TypeScript          28      6,210     201,332
...
TOTAL               92    17,981     601,200
```

## Gotchas

- **tokei vs cloc**: tokei is faster and handles more languages out of the box; recommend `cargo install tokei` or `brew install tokei`.
- **Heuristic counts blanks/comments**: don't pass this off as code-only LOC. Print the disclaimer.
- **`.git` directory**: always exclude — submodules can balloon counts.
- **Symlinks**: `os.walk` follows them by default. For repos with weird linked vendor dirs, pass `--exclude` explicitly.
- **Vendor/generated code**: tokei doesn't auto-detect minified or generated files. Manual exclude.
- **Binary in `.svg`/`.json`**: large fixtures inflate counts. Acceptable for a quick overview, misleading for code-quality reports.

## Cross-Platform Notes

- **macOS**: `brew install tokei`
- **Linux**: `cargo install tokei` or distro packages where available
- **Windows**: scoop/chocolatey have tokei. Heuristic mode requires only `python3`.
