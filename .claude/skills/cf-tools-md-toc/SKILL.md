---
name: cf-tools-md-toc
description: "Generate or refresh a Markdown table of contents from heading hierarchy. Trigger: /cf-tools-md-toc"
trigger: /cf-tools-md-toc
version: 1.0.0
---

# /cf-tools-md-toc

Scan a Markdown file's headings (`#`, `##`, `###`, …) and emit a nested bullet ToC. If the file contains an `<!-- TOC -->` … `<!-- /TOC -->` marker, the ToC is injected between them in-place; otherwise the ToC is printed to stdout.

## Usage

```
/cf-tools-md-toc README.md                    # print ToC to stdout
/cf-tools-md-toc README.md --in-place         # inject between <!-- TOC --> markers
/cf-tools-md-toc README.md --depth 3          # limit to H1-H3
/cf-tools-md-toc README.md --skip-h1          # omit H1 (common when H1 is the title)
```

Arguments:
1. `md-path` (required) — markdown file
2. `--in-place` (optional flag) — modify the file between TOC markers
3. `--depth N` (optional, default 6) — max heading depth to include
4. `--skip-h1` (optional flag) — exclude H1 headings

## Marker convention

To enable in-place injection, the target file must contain:

```markdown
<!-- TOC -->
(anything here gets replaced)
<!-- /TOC -->
```

Without markers, `--in-place` is a no-op (script reports "no markers found, printing to stdout instead").

## What You Must Do When Invoked

Single self-contained bash+python implementation (no external deps beyond Python 3):

```bash
MD_PATH="$1"; shift
IN_PLACE=0; DEPTH=6; SKIP_H1=0
while [ $# -gt 0 ]; do
  case "$1" in
    --in-place) IN_PLACE=1; shift ;;
    --depth) DEPTH="$2"; shift 2 ;;
    --skip-h1) SKIP_H1=1; shift ;;
    *) shift ;;
  esac
done

[ ! -f "$MD_PATH" ] && { echo "ERROR: not found: $MD_PATH" >&2; exit 1; }

python3 - "$MD_PATH" "$IN_PLACE" "$DEPTH" "$SKIP_H1" <<'PY'
import sys, re, pathlib

path, in_place, max_depth, skip_h1 = sys.argv[1], sys.argv[2]=="1", int(sys.argv[3]), sys.argv[4]=="1"
text = pathlib.Path(path).read_text(encoding="utf-8")

# Strip fenced code blocks so headings inside them don't count
def strip_fences(s):
    out, in_fence = [], False
    for line in s.splitlines(keepends=True):
        if re.match(r'^[ \t]*```', line):
            in_fence = not in_fence
            out.append(line)
            continue
        if not in_fence:
            out.append(line)
        else:
            out.append("\n")  # placeholder to preserve line numbers
    return "".join(out)

scan = strip_fences(text)

# Match ATX headings: ## Title  (allow trailing #s, ignore setext-style)
HEADING = re.compile(r'^(#{1,6})\s+(.+?)\s*#*\s*$', re.MULTILINE)

def slugify(title):
    s = title.strip().lower()
    s = re.sub(r'[^\w\s-]', '', s)
    s = re.sub(r'\s+', '-', s)
    return s

items = []
for m in HEADING.finditer(scan):
    level = len(m.group(1))
    if level > max_depth: continue
    if skip_h1 and level == 1: continue
    title = m.group(2).strip()
    # Strip markdown formatting in title for ToC text
    text_only = re.sub(r'`([^`]+)`', r'\1', title)
    text_only = re.sub(r'\*\*([^*]+)\*\*', r'\1', text_only)
    text_only = re.sub(r'\*([^*]+)\*', r'\1', text_only)
    items.append((level, text_only, slugify(title)))

if not items:
    print("(no headings found)", file=sys.stderr)
    sys.exit(0)

# Normalize so the shallowest level becomes indent 0
base = min(lvl for lvl,_,_ in items)
lines = []
for lvl, text_only, slug in items:
    indent = "  " * (lvl - base)
    lines.append(f"{indent}- [{text_only}](#{slug})")
toc = "\n".join(lines)

MARKER_RE = re.compile(r'(<!--\s*TOC\s*-->)(.*?)(<!--\s*/TOC\s*-->)', re.DOTALL)

if in_place:
    if MARKER_RE.search(text):
        new_text = MARKER_RE.sub(lambda m: f"{m.group(1)}\n\n{toc}\n\n{m.group(3)}", text)
        pathlib.Path(path).write_text(new_text, encoding="utf-8")
        print(f"OK: injected ToC into {path} ({len(items)} headings)", file=sys.stderr)
    else:
        print("WARN: no <!-- TOC --> markers in file. Printing to stdout instead:", file=sys.stderr)
        print(toc)
else:
    print(toc)
PY
```

## Output Contract

stdout mode:
```
- [Heading 1](#heading-1)
  - [Sub heading](#sub-heading)
- [Heading 2](#heading-2)
```

in-place mode: file is edited; stderr reports `OK: injected ToC into <path> (N headings)`.

## Gotchas

- **Setext-style headings** (`Title\n=====`) are NOT detected — only ATX (`# Title`). Convert with `pandoc -f markdown -t gfm` first if needed.
- **Headings inside fenced code blocks** are correctly ignored (the strip_fences pre-pass).
- **Slug generation** mimics GitHub's algorithm: lowercase, remove punctuation, spaces → hyphens. It does NOT deduplicate (`# Foo` twice produces two `#foo` anchors that GitHub auto-suffixes as `#foo-1`).
- **Emoji and Unicode** in headings — slugify strips non-`\w` characters; for non-ASCII headings, GitHub keeps them as-is (use a custom slugifier if exact match required).
- **HTML tags inside headings** (`# <span>Title</span>`) leak into ToC text. Strip with `re.sub(r'<[^>]+>', '', text)` if your source uses inline HTML.
- **Marker injection is whitespace-tolerant** — matches `<!-- TOC -->`, `<!--TOC-->`, `<!--  TOC  -->` equally.
- **Always run with `--in-place` after editing headings** to keep the ToC current — consider a pre-commit hook.

## Cross-Platform Notes

- **Pure Python 3** — no external installs. Works wherever `python3` is on PATH.
- **No GitHub/GitLab API call** — slugs match GitHub's renderer for ASCII headings; deeply Unicode-heavy docs may need a server-side preview to confirm anchors.
