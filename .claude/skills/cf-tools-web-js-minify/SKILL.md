---
name: cf-tools-web-js-minify
description: "Minify JavaScript via terser with source maps and savings report. Trigger: /cf-tools-web-js-minify"
trigger: /cf-tools-web-js-minify
version: 1.0.0
---

# /cf-tools-web-js-minify

Minify a JavaScript file with `terser`. Defaults to ECMAScript 2020 target,
mangles local names, and emits a source map. Returns before/after byte counts
and savings percentage.

## Usage

```
/cf-tools-web-js-minify ./app.js                          # → app.min.js
/cf-tools-web-js-minify ./app.js ./dist/app.min.js        # explicit output
/cf-tools-web-js-minify ./app.js --no-map                 # skip source map
/cf-tools-web-js-minify ./app.js --keep-names             # preserve fn/class names
```

Arguments:
1. `input` (required) — path to source JS (can be ES module)
2. `output` (optional, default `<stem>.min.js`)
3. `--no-map` (optional flag) — skip source map
4. `--keep-names` (optional flag) — preserve function/class names (for stack traces)

## Install

```bash
npm install -g terser
# verify
terser --version
```

## What You Must Do When Invoked

### Step 1 — Validate

```bash
SRC="$1"
[ -f "$SRC" ] || { echo "ERROR: not found: $SRC"; exit 1; }
ORIG_SIZE=$(wc -c < "$SRC" | tr -d ' ')

OUT="${2:-${SRC%.js}.min.js}"
case "$OUT" in --*) OUT="${SRC%.js}.min.js" ;; esac

NO_MAP=0; KEEP_NAMES=0
for arg in "$@"; do
  [ "$arg" = "--no-map" ]    && NO_MAP=1
  [ "$arg" = "--keep-names" ] && KEEP_NAMES=1
done
```

### Step 2 — Verify terser installed

```bash
if ! command -v terser >/dev/null 2>&1; then
  echo "ERROR: terser not installed. Run: npm install -g terser"
  exit 1
fi
```

### Step 3 — Build args and run

```bash
ARGS=(--compress --mangle --ecma 2020)
[ "$KEEP_NAMES" -eq 1 ] && ARGS+=(--keep-fnames --keep-classnames)
[ "$NO_MAP"     -eq 0 ] && ARGS+=(--source-map "url=$(basename "$OUT").map")

terser "$SRC" "${ARGS[@]}" -o "$OUT"
```

### Step 4 — Report

```bash
MIN_SIZE=$(wc -c < "$OUT" | tr -d ' ')
SAVED=$((ORIG_SIZE - MIN_SIZE))
PCT=$((SAVED * 100 / ORIG_SIZE))
echo "✅ terser: $ORIG_SIZE → $MIN_SIZE bytes ($PCT% saved) → $OUT"
```

## Output Contract

```
## JS Minified

**Input:**     <path>  (<bytes>)
**Output:**    <path>  (<bytes>)
**Saved:**     <bytes> (<pct>%)
**Tool:**      terser <version>
**ECMA:**      2020 (default)
**Map:**       <path>.map | (skipped)
**Names:**     mangled | preserved (--keep-names)
```

## Gotchas

- **`eval` blocks code mangling** — terser detects `eval` / `with` and disables
  rename in that scope. Output stays correct but larger.
- **Top-level `var` is hoisted/inlined** — pass `--toplevel` to extend mangling
  to top-level names. Only do this for IIFE-wrapped or ES-module files.
- **ESM `import`/`export` preserved** — terser outputs ESM if input is ESM. Use
  `--module` flag to be explicit.
- **Stack traces become unreadable** — mangled `a`, `b`, `c` names destroy
  production stack traces. Either ship source maps to your error tracker or use
  `--keep-names`.
- **`/*! preserve */` and `@license` comments survive** — only those. All other
  comments stripped. Use `--comments all` to keep everything (rarely needed).
- **No tree-shaking** — terser is a single-file minifier; it can't drop dead
  imports across files. Use Rollup or esbuild for bundle-level shrinkage first.

## Cross-Platform Notes

terser is pure Node, identical across macOS / Linux / Windows. For large files
(>5MB) on low-memory machines pass `NODE_OPTIONS=--max-old-space-size=4096`.
