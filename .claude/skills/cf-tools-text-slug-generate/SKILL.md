---
name: cf-tools-text-slug-generate
description: "Convert text into URL-safe slug — lowercase, hyphenated, accent-folded. Trigger: /cf-tools-text-slug-generate"
trigger: /cf-tools-text-slug-generate
version: 1.0.0
---

# /cf-tools-text-slug-generate

Turn arbitrary text ("Café Résumé Naïve!") into a URL-safe slug ("cafe-resume-naive"). Handles unicode by folding accents to ASCII, lowercases, replaces non-alphanumeric runs with single hyphens, and trims leading/trailing dashes.

## Usage

```
echo "Hello World!" | /cf-tools-text-slug-generate
/cf-tools-text-slug-generate "Café & Résumé"
/cf-tools-text-slug-generate input.txt --batch         # one slug per line
/cf-tools-text-slug-generate "Foo Bar" --sep _         # use underscore instead
/cf-tools-text-slug-generate "Foo Bar" --max 30        # cap length
```

Arguments:
1. `input` (required) — text string or file path
2. `--batch` (optional) — treat input as a file with one entry per line
3. `--sep CHAR` (optional, default `-`) — separator character
4. `--max N` (optional) — truncate slug to N chars (trim at last separator)
5. `--allow-unicode` (optional) — keep unicode letters instead of folding to ASCII

## Self-Contained Snippet

```bash
TEXT="${1:-$(cat)}"
python3 - "$TEXT" <<'PY'
import sys, unicodedata, re
t = sys.argv[1].lower()
t = unicodedata.normalize('NFKD', t).encode('ascii','ignore').decode('ascii')
slug = re.sub(r'[^a-z0-9]+', '-', t).strip('-')
print(slug)
PY
```

## What You Must Do When Invoked

### Step 1 — Parse flags

```bash
SEP="-"; MAX=0; BATCH=0; UNICODE=0; ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --batch) BATCH=1; shift;;
    --sep) SEP="$2"; shift 2;;
    --max) MAX="$2"; shift 2;;
    --allow-unicode) UNICODE=1; shift;;
    *) ARG="$1"; shift;;
  esac
done
```

### Step 2 — Build input list

```bash
if [ "$BATCH" -eq 1 ] && [ -f "$ARG" ]; then
  INPUT=$(cat "$ARG")
elif [ -n "$ARG" ]; then
  INPUT="$ARG"
else
  INPUT=$(cat)
fi
```

### Step 3 — Slugify

```bash
python3 - "$SEP" "$MAX" "$UNICODE" <<PY
import sys, unicodedata, re
sep, maxlen, unicode_ok = sys.argv[1], int(sys.argv[2]), sys.argv[3] == "1"
text = """$INPUT"""

def slugify(s):
    s = s.strip().lower()
    if not unicode_ok:
        s = unicodedata.normalize('NFKD', s).encode('ascii','ignore').decode('ascii')
    else:
        s = unicodedata.normalize('NFKC', s)
    # Replace non-word runs with separator
    pattern = r'[^a-z0-9]+' if not unicode_ok else r'[^\w]+'
    s = re.sub(pattern, sep, s, flags=re.UNICODE)
    s = s.strip(sep)
    if maxlen > 0 and len(s) > maxlen:
        s = s[:maxlen].rsplit(sep, 1)[0]
    return s

for line in text.splitlines() or [text]:
    if line.strip():
        print(slugify(line))
PY
```

## Output Contract

```
## Slug generation

Source:    <text-or-file>
Separator: <char>
Max len:   <N or unlimited>
Mode:      ascii-fold | preserve-unicode
Lines:     <N>

<slug(s)>
```

## Gotchas

- **`iconv -t ASCII//TRANSLIT` on macOS produces junk**: BSD iconv emits `caf'e` for `café`. **Always use Python `unicodedata.normalize('NFKD')` instead** — works identically across macOS, Linux, Windows.
- **Empty result**: if all chars were non-alphanumeric (e.g. `"@@@"`), the slug becomes empty. Either return `""` or fail loudly — pick one and document.
- **Trailing separator after `--max`**: truncating mid-word leaves a partial; the `rsplit(sep, 1)[0]` trick cuts at the last separator boundary.
- **Numbers-only slugs**: `"2024"` slugifies to `"2024"`. Valid URL but not unique — caller should append a hash if uniqueness matters.
- **`--allow-unicode` URL behavior**: modern browsers percent-encode unicode segments fine, but some legacy systems break. Default to ASCII fold.
- **`ß` → `ss`?**: NFKD turns `ß` into `ß` (no decomposition). To get `ss` use `s.replace("ß","ss")` before normalizing. Same for `æ → ae`, `œ → oe`.

## Cross-Platform Notes

- **macOS**: Python 3 ships in `/usr/bin/python3` (3.9+ on Sonoma).
- **Linux**: Python 3.6+ standard.
- **`unidecode` library** offers better transliteration (`京 → Jing`) — install via `pip install unidecode` if you need CJK support; this skill stays stdlib-only.
- **GNU iconv** also gives different output than BSD; portability is exactly why this skill avoids iconv.
