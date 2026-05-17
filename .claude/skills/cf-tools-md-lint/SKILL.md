---
name: cf-tools-md-lint
description: "Lint Markdown files for style issues using markdownlint-cli. Trigger: /cf-tools-md-lint"
trigger: /cf-tools-md-lint
version: 1.0.0
---

# /cf-tools-md-lint

Run `markdownlint-cli` against one or more Markdown files (or a glob) and report rule violations with line numbers. Optionally apply autofixes (`--fix`).

## Required tool — markdownlint-cli

This skill depends on `markdownlint-cli`, which is NOT installed by default. Install once:

```bash
npm install -g markdownlint-cli         # all platforms
# OR for the newer Rust-style port with more rules:
npm install -g markdownlint-cli2
```

Verify: `markdownlint --version` should print `0.x.x` or higher.

## Usage

```
/cf-tools-md-lint README.md
/cf-tools-md-lint "docs/**/*.md"
/cf-tools-md-lint README.md --fix                       # autofix in place
/cf-tools-md-lint docs/ --config .markdownlint.json     # custom rules
/cf-tools-md-lint docs/ --json                          # JSON output for CI
```

Arguments:
1. `path-or-glob` (required) — single file, directory, or glob
2. `--fix` (optional flag) — apply autofixes in place
3. `--config <path>` (optional) — config file (default: `.markdownlint.json` if present)
4. `--json` (optional flag) — emit machine-readable JSON

## What You Must Do When Invoked

### Step 1 — Verify tool

```bash
if ! command -v markdownlint >/dev/null 2>&1; then
  echo "ERROR: markdownlint not installed." >&2
  echo "Install: npm install -g markdownlint-cli" >&2
  exit 1
fi
```

### Step 2 — Build sensible default config (if none exists)

If neither `--config` is passed nor `.markdownlint.json` exists in the project, write a temp config with permissive defaults so the user doesn't get blasted by 50+ violations on day one:

```bash
TARGET="$1"; shift
FIX_FLAG=""
CONFIG=""
JSON_FLAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fix) FIX_FLAG="--fix"; shift ;;
    --config) CONFIG="$2"; shift 2 ;;
    --json) JSON_FLAG="--json"; shift ;;
    *) shift ;;
  esac
done

if [ -z "$CONFIG" ] && [ ! -f .markdownlint.json ]; then
  CONFIG="$(mktemp -t mdlint.XXXXXX.json)"
  cat > "$CONFIG" <<'JSON'
{
  "default": true,
  "MD013": false,
  "MD024": { "siblings_only": true },
  "MD033": false,
  "MD041": false
}
JSON
  echo "Using temp default config (MD013/MD033/MD041 disabled): $CONFIG" >&2
fi
```

What the defaults disable:
- **MD013** — line length (off; prose lines vary)
- **MD024** — duplicate headings (siblings only; identical sub-headings under different parents OK)
- **MD033** — inline HTML (off; common in README badges)
- **MD041** — first line H1 (off; some docs start with frontmatter)

### Step 3 — Run

```bash
CMD=(markdownlint)
[ -n "$CONFIG" ] && CMD+=(--config "$CONFIG")
[ -n "$FIX_FLAG" ] && CMD+=("$FIX_FLAG")
[ -n "$JSON_FLAG" ] && CMD+=("$JSON_FLAG")
CMD+=("$TARGET")

echo "Running: ${CMD[*]}" >&2
"${CMD[@]}"
RC=$?

if [ "$RC" -eq 0 ]; then
  echo "✅ No issues in $TARGET" >&2
else
  echo "❌ Lint found issues (exit $RC)" >&2
fi
exit $RC
```

## Expected output

Without violations:
```
✅ No issues in README.md
```

With violations:
```
README.md:14 MD009/no-trailing-spaces Trailing spaces [Expected: 0 or 2; Actual: 1]
README.md:22 MD031/blanks-around-fences Fenced code blocks should be surrounded by blank lines
README.md:40 MD040/fenced-code-language Fenced code blocks should have a language specified
```

JSON mode emits an array of `{ fileName, lineNumber, ruleNames, ruleDescription, ruleInformation }` records.

## Common rules and meanings

| Rule | Meaning |
|---|---|
| MD001 | heading levels increment by one (no `# → ###` jumps) |
| MD009 | no trailing spaces (except double-space for line break) |
| MD012 | no multiple consecutive blank lines |
| MD018 | hash + space after `#` (no `#NoSpace`) |
| MD022 | headings surrounded by blank lines |
| MD025 | only one H1 per document |
| MD031 | blank lines around fenced code |
| MD034 | bare URLs must be wrapped in `<...>` |
| MD040 | fences must declare a language |
| MD047 | file must end with a single newline |

Full rule reference: https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md

## Output Contract

```
## Markdown lint

**Target:**   <path-or-glob>
**Config:**   <config-path or "temp defaults">
**Violations:** <N>
**Fixed:**     <M> (only with --fix)
**Exit:**      0 (clean) | 1 (issues)
```

## Gotchas

- **Glob expansion**: quote globs (`"docs/**/*.md"`) so the shell doesn't pre-expand. markdownlint-cli handles globs natively.
- **`--fix` is destructive** — always commit or stash before running with `--fix` on a real project.
- **`MD013` line length** is the noisiest rule for prose. Either disable (default here) or set `"MD013": { "line_length": 120, "tables": false, "code_blocks": false }`.
- **Frontmatter** (`---\n...\n---`) — markdownlint treats it as content. If your docs use YAML/TOML frontmatter heavily, set `"MD041": false` (disabled by default here).
- **markdownlint-cli2** is the newer fork with `.markdownlint-cli2.jsonc` config and parallel runs; consider it for monorepos.
- **CI mode**: `markdownlint --json | jq` is useful for failing PRs; the default human format isn't great for parsing.

## Cross-Platform Notes

- **macOS / Linux / Windows**: same npm install. Requires Node 14+.
- **No native binary** — pure Node.js, ships as the `markdownlint` CLI on `$PATH` after `npm install -g`.
- **Pre-commit hook**: integrate via `pre-commit` framework with `https://github.com/igorshubovych/markdownlint-cli`.
