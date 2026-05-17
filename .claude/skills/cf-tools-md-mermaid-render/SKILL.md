---
name: cf-tools-md-mermaid-render
description: "Extract Mermaid fenced code blocks from a Markdown file and render each to PNG or SVG via mermaid-cli. Trigger: /cf-tools-md-mermaid-render"
trigger: /cf-tools-md-mermaid-render
version: 1.0.0
---

# /cf-tools-md-mermaid-render

Scan a Markdown file for ```` ```mermaid ```` fenced blocks, extract each one to a `.mmd` source file, and render to PNG or SVG via `mmdc` (mermaid-cli). Useful for producing static diagrams from docs that GitHub renders natively but other viewers (PDF, slides, blog platforms) don't.

## Prerequisites

`mmdc` is **not** bundled. Install once:

```bash
npm i -g @mermaid-js/mermaid-cli
```

This pulls in Puppeteer (~250MB) the first time. The skill must detect `mmdc` and refuse with the install instruction if missing — **do not** attempt a live render without it.

A known-good standalone invocation (copy-paste this if `mmdc` is on PATH):

```bash
mmdc -i input.mmd -o out.png -b white -w 1600 -H 1000
```

## Usage

```
/cf-tools-md-mermaid-render <markdown-file>
/cf-tools-md-mermaid-render <markdown-file> --format svg
/cf-tools-md-mermaid-render <markdown-file> --out-dir /path/diagrams
/cf-tools-md-mermaid-render <markdown-file> --theme dark
```

Arguments:
1. `markdown-file` (required)
2. `--format <png|svg>` (optional, default `png`)
3. `--out-dir <dir>` (optional, default `<md-stem>.diagrams/` next to source)
4. `--theme <default|dark|forest|neutral>` (optional, default `default`)

## What You Must Do When Invoked

### Step 1 — Tool check (refuse fast if missing)

```bash
if ! command -v mmdc >/dev/null 2>&1; then
  cat <<'EOF'
ERROR: mmdc (mermaid-cli) is required for this skill.

Install with:
    npm i -g @mermaid-js/mermaid-cli

Then re-run. If npm-global is restricted, try:
    npx -y @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.png
EOF
  exit 1
fi
```

### Step 2 — Parse args + prepare out dir

```bash
MD="$1"
[ ! -f "$MD" ] && { echo "ERROR: $MD not found"; exit 1; }
FORMAT="png"; THEME="default"; OUT_DIR=""
prev=""
for a in "$@"; do
  case "$prev" in
    --format)  FORMAT="$a" ;;
    --out-dir) OUT_DIR="$a" ;;
    --theme)   THEME="$a" ;;
  esac
  prev="$a"
done

STEM="$(basename "${MD%.md}")"
[ -z "$OUT_DIR" ] && OUT_DIR="$(dirname "$MD")/${STEM}.diagrams"
mkdir -p "$OUT_DIR"
```

### Step 3 — Extract mermaid blocks

```bash
python3 - "$MD" "$OUT_DIR" <<'PY'
import sys, re, pathlib
md = pathlib.Path(sys.argv[1]).read_text()
out_dir = pathlib.Path(sys.argv[2])
# Match ```mermaid ... ```  (non-greedy, multi-line, allow trailing infostring)
pattern = re.compile(r"```mermaid\s*\n(.*?)\n```", re.DOTALL)
for i, m in enumerate(pattern.finditer(md), start=1):
    path = out_dir / f"diagram-{i:02d}.mmd"
    path.write_text(m.group(1).strip() + "\n")
    print(path)
PY
```

### Step 4 — Render each .mmd → .png|.svg

```bash
RENDERED=0
for src in "$OUT_DIR"/diagram-*.mmd; do
  [ -e "$src" ] || break
  dst="${src%.mmd}.${FORMAT}"
  mmdc -i "$src" -o "$dst" -b white -t "$THEME" -w 1600 -H 1000 2>/dev/null
  if [ -s "$dst" ]; then
    echo "OK $dst ($(wc -c < "$dst" | tr -d ' ') bytes)"
    RENDERED=$((RENDERED + 1))
  else
    echo "FAIL $src — mmdc did not produce output"
  fi
done

if [ "$RENDERED" -eq 0 ]; then
  echo "WARNING: no mermaid blocks found in $MD"
fi
echo "Rendered $RENDERED diagram(s) to $OUT_DIR"
```

## Output Contract

```
## Markdown Mermaid → Images

**Source:**     <md-path>
**Out dir:**    <dir>
**Format:**     png|svg
**Theme:**      default|dark|forest|neutral
**Diagrams:**   <N rendered>  (sources kept as .mmd alongside)
**mmdc:**       <version from `mmdc --version`>
```

## Gotchas

- **Puppeteer download on first install**: `npm i -g @mermaid-js/mermaid-cli` will pull Chromium (~250MB). If behind a proxy, set `PUPPETEER_DOWNLOAD_HOST` or use `--puppeteerConfigFile`.
- **`mmdc` crashes with "Failed to launch the browser process"**: on Linux servers, install required libs first: `apt install libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libgbm1 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libpango-1.0-0 libcairo2 libasound2`.
- **SVG output and transparent background**: pass `-b transparent` instead of `-b white` if you need that. Default skill uses white for slide friendliness.
- **Diagrams with multiple sub-diagrams**: each ` ```mermaid ` block is rendered independently. Don't merge.
- **Code block fences inside the diagram**: rare, but if a mermaid block contains backticks, the regex stops at the first ` ``` `. Sanitize first.
- **Output dir collisions on re-run**: this overwrites `diagram-01.mmd` etc without prompting. That's intentional for idempotence; copy old outputs first if you need diffs.

## Cross-Platform Notes

- `mmdc` runs on Node ≥ 16 — same on macOS/Linux/Windows. Confirm with `node --version`.
- For one-off renders without global install: `npx -y @mermaid-js/mermaid-cli -i in.mmd -o out.png`.
- CI: cache `~/.cache/puppeteer` between runs to avoid re-downloading Chromium on every build.
