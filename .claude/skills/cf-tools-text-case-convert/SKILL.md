---
name: cf-tools-text-case-convert
description: "Convert text between snake_case, camelCase, kebab-case, PascalCase, UPPER, lower, Title Case. Trigger: /cf-tools-text-case-convert"
trigger: /cf-tools-text-case-convert
version: 1.0.0
---

# /cf-tools-text-case-convert

Convert identifiers between common casing styles. Reads stdin or a file. Auto-detects source case when `--from` isn't supplied.

## Usage

```
echo "hello world" | /cf-tools-text-case-convert --to kebab
echo "myVarName" | /cf-tools-text-case-convert --to snake
/cf-tools-text-case-convert input.txt --to pascal
/cf-tools-text-case-convert input.txt --from snake --to camel
echo "FOO BAR" | /cf-tools-text-case-convert --to title
```

Arguments:
1. `input` (optional) — file path; stdin if omitted
2. `--to STYLE` (required) — target style: `snake`, `camel`, `kebab`, `pascal`, `upper`, `lower`, `title`
3. `--from STYLE` (optional, default `auto`) — source style hint

## Self-Contained Snippet

```bash
TO="$1"; INPUT="${2:-/dev/stdin}"
python3 - "$TO" < "$INPUT" <<'PY'
import sys, re
to=sys.argv[1]; t=sys.stdin.read().strip()
words = re.findall(r'[A-Z]+(?=[A-Z][a-z])|[A-Z]?[a-z]+|[A-Z]+|\d+', t) or t.split()
words = [w.lower() for w in words]
print({'snake':'_'.join,'kebab':'-'.join,'camel':lambda w:w[0]+''.join(s.title() for s in w[1:]),'pascal':lambda w:''.join(s.title() for s in w),'upper':lambda w:'_'.join(w).upper(),'lower':' '.join,'title':lambda w:' '.join(s.title() for s in w)}[to](words))
PY
```

## What You Must Do When Invoked

### Step 1 — Parse flags

```bash
TO=""; FROM="auto"; INPUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --to) TO="$2"; shift 2;;
    --from) FROM="$2"; shift 2;;
    *) INPUT="$1"; shift;;
  esac
done
[ -n "$TO" ] || { echo "ERROR: --to required"; exit 1; }
```

### Step 2 — Read input

```bash
if [ -n "$INPUT" ]; then
  [ -f "$INPUT" ] || { echo "ERROR: file not found: $INPUT"; exit 1; }
  SRC=$(cat "$INPUT")
else
  SRC=$(cat)
fi
```

### Step 3 — Tokenize then re-emit

```bash
python3 - "$TO" "$FROM" <<PY
import sys, re
to, frm = sys.argv[1], sys.argv[2]
text = """$SRC"""

def tokenize(s, frm):
    if frm == "snake":  return s.lower().split("_")
    if frm == "kebab":  return s.lower().split("-")
    if frm in ("camel","pascal"):
        return [w.lower() for w in re.findall(r'[A-Z]+(?=[A-Z][a-z])|[A-Z]?[a-z]+|[A-Z]+|\d+', s)]
    # auto / lower / upper / title
    return [w.lower() for w in re.findall(r'[A-Z]+(?=[A-Z][a-z])|[A-Z]?[a-z]+|[A-Z]+|\d+', s)] or s.split()

def emit(words, to):
    if to == "snake":  return "_".join(words)
    if to == "kebab":  return "-".join(words)
    if to == "camel":  return words[0] + "".join(w.title() for w in words[1:]) if words else ""
    if to == "pascal": return "".join(w.title() for w in words)
    if to == "upper":  return "_".join(words).upper()
    if to == "lower":  return " ".join(words)
    if to == "title":  return " ".join(w.title() for w in words)
    raise SystemExit(f"unknown style: {to}")

for line in text.splitlines():
    print(emit(tokenize(line, frm), to))
PY
```

## Output Contract

```
## Case convert

From:  <auto|snake|kebab|camel|pascal>
To:    <snake|kebab|camel|pascal|upper|lower|title>
Lines: <N>

<converted text>
```

## Gotchas

- **Acronyms**: `XMLParser` → snake should be `xml_parser`, not `x_m_l_parser`. The regex `[A-Z]+(?=[A-Z][a-z])` handles this — treats consecutive caps before a cap+lower as one token.
- **Numbers**: `version2Beta` → `version_2_beta`. Keep digits as separate tokens.
- **Empty lines**: pass through unchanged. The `for line in text.splitlines()` loop preserves blank lines.
- **Non-ASCII**: Python regex `\w` is unicode-aware by default. Use `re.ASCII` flag if you want strict ASCII tokenization.
- **Locale-dependent title case**: `'i'.title()` in Turkish locale gives different results. The Python implementation here uses default C locale, which is consistent.

## Cross-Platform Notes

- **Python 3** required (3.6+). Ships with macOS, most Linux distros, modern WSL.
- **No bash-only fallback**: shell case conversion (`tr '[:upper:]' '[:lower:]'`) doesn't understand word boundaries — can't do camel ↔ snake.
- **Editor integrations**: VS Code has `Change Case` extension; this skill is for shell/script contexts.
