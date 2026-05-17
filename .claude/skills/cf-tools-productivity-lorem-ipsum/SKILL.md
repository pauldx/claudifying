---
name: cf-tools-productivity-lorem-ipsum
description: "Generate placeholder lorem ipsum text — N paragraphs, sentences, or words, optionally as HTML. Trigger: /cf-tools-productivity-lorem-ipsum"
trigger: /cf-tools-productivity-lorem-ipsum
version: 1.0.0
---

# /cf-tools-productivity-lorem-ipsum

Produce filler text for mockups. No network calls — corpus is hand-rolled inline. Output as plain text, paragraphs, sentences, or wrapped in HTML `<p>` tags.

## Usage

```
/cf-tools-productivity-lorem-ipsum                       # 3 paragraphs (default)
/cf-tools-productivity-lorem-ipsum --paragraphs 5
/cf-tools-productivity-lorem-ipsum --sentences 4
/cf-tools-productivity-lorem-ipsum --words 50
/cf-tools-productivity-lorem-ipsum --paragraphs 2 --html
```

Arguments:
- `--paragraphs <N>` — generate N paragraphs (default if no unit given: 3)
- `--sentences <N>` — generate N sentences
- `--words <N>` — generate exactly N words
- `--html` — wrap paragraphs in `<p>...</p>`
- `--seed <int>` — reproducible output (uses Python `random.seed`)

## What You Must Do When Invoked

### Step 1 — Run the generator

```bash
python3 - "$@" <<'PY'
import sys, random, textwrap

CORPUS = (
    "lorem ipsum dolor sit amet consectetur adipiscing elit sed do "
    "eiusmod tempor incididunt ut labore et dolore magna aliqua enim "
    "ad minim veniam quis nostrud exercitation ullamco laboris nisi ut "
    "aliquip ex ea commodo consequat duis aute irure dolor in "
    "reprehenderit voluptate velit esse cillum fugiat nulla pariatur "
    "excepteur sint occaecat cupidatat non proident sunt in culpa qui "
    "officia deserunt mollit anim id est laborum at vero eos et "
    "accusamus iusto odio dignissimos ducimus blanditiis praesentium "
    "voluptatum deleniti atque corrupti quos dolores quas molestias "
    "excepturi sint occaecati cupiditate non provident similique sunt "
    "culpa officia deserunt mollitia animi laborum dolorum fuga harum "
    "quidem rerum facilis expedita distinctio nam libero tempore cum "
    "soluta nobis eligendi optio cumque nihil impedit quo minus quod "
    "maxime placeat facere possimus omnis voluptas assumenda est omnis "
    "dolor repellendus temporibus autem quibusdam officiis debitis aut "
    "rerum necessitatibus saepe eveniet voluptates repudiandae sint et "
    "molestiae recusandae itaque earum hic tenetur a sapiente delectus "
    "ut aut reiciendis voluptatibus maiores alias consequatur aut "
    "perferendis doloribus asperiores repellat"
).split()

args = sys.argv[1:]
mode = "paragraphs"; count = 3
html = False; seed = None
i = 0
while i < len(args):
    a = args[i]
    if a == "--paragraphs": mode, count = "paragraphs", int(args[i+1]); i += 2
    elif a == "--sentences": mode, count = "sentences", int(args[i+1]); i += 2
    elif a == "--words":     mode, count = "words", int(args[i+1]); i += 2
    elif a == "--html":      html = True; i += 1
    elif a == "--seed":      seed = int(args[i+1]); i += 2
    else: i += 1

if seed is not None:
    random.seed(seed)

def words(n):
    return [random.choice(CORPUS) for _ in range(n)]

def sentence():
    n = random.randint(8, 18)
    w = words(n)
    w[0] = w[0].capitalize()
    return " ".join(w) + random.choice([".", ".", ".", "?", "!"])

def paragraph():
    return " ".join(sentence() for _ in range(random.randint(3, 6)))

if mode == "words":
    w = words(count)
    if w: w[0] = w[0].capitalize()
    out = " ".join(w) + "."
    print(textwrap.fill(out, 80))
elif mode == "sentences":
    out = " ".join(sentence() for _ in range(count))
    print(textwrap.fill(out, 80))
else:  # paragraphs
    paras = [paragraph() for _ in range(count)]
    if html:
        for p in paras:
            print(f"<p>{p}</p>")
    else:
        for p in paras:
            print(textwrap.fill(p, 80))
            print()
PY
```

### Step 2 — Report

```bash
echo ""
echo "✅ Generated <count> <unit>${html:+ (HTML)}"
```

## Output Contract

```
## Lorem ipsum
**Mode:**      paragraphs | sentences | words
**Count:**     <N>
**HTML:**      yes | no
**Seed:**      <int or "random">

<generated text follows>
```

## Gotchas

- **Empty output**: if `--words 0` or `--paragraphs 0`, the generator stays silent. Validate and refuse non-positive counts before running.
- **Always starts with "Lorem ipsum…"?**: classic lorem ipsum starts with that phrase. This generator does NOT lock the first word — for the canonical opener, prepend it manually or wire a `--canonical` flag.
- **HTML wraps paragraphs only**: sentence- and word-mode ignore `--html` to avoid generating malformed snippets.
- **Reproducibility**: without `--seed`, output is non-deterministic. CI golden-file tests should always pass a seed.
- **Punctuation density**: tuned for blog-like prose. Tweak the `random.choice([".", ".", ".", "?", "!"])` tuple for different styles.

## Cross-Platform Notes

- Pure Python 3 — works on any platform with `python3` (3.6+).
- No external deps, no network.
- Use `--seed 42` in tests; reuse the same seed across machines for identical output.
