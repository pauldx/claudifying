---
name: cf-tools-archive-zip-create
description: "Create a .zip archive from a directory with exclude patterns and a size-before/after summary. Trigger: /cf-tools-archive-zip-create"
trigger: /cf-tools-archive-zip-create
version: 1.0.0
---

# /cf-tools-archive-zip-create

Pack a directory into a `.zip` using the built-in `zip` tool. Supports glob excludes and reports compression ratio.

## Usage

```
/cf-tools-archive-zip-create src/                      # → src.zip
/cf-tools-archive-zip-create src/ release.zip
/cf-tools-archive-zip-create src/ release.zip --exclude '*.log' --exclude 'node_modules/*'
/cf-tools-archive-zip-create src/ release.zip --level 9  # max compression
```

Arguments:
1. `source` (required) — directory or file
2. `output` (optional, default `<basename>.zip`) — archive path
3. `--exclude <pattern>` — glob to skip (repeatable)
4. `--level <0-9>` — compression level (default 6; 0 = store only, 9 = max)

## What You Must Do When Invoked

### Step 1 — Validate

```bash
SRC="$1"
[ -e "$SRC" ] || { echo "ERROR: source not found: $SRC"; exit 1; }

if ! command -v zip >/dev/null 2>&1; then
  echo "ERROR: zip not installed. macOS: built-in. Linux: sudo apt install zip"
  exit 2
fi

OUTPUT="${2:-$(basename "$SRC").zip}"
LEVEL="${LEVEL:-6}"
```

### Step 2 — Size before

```bash
SRC_BYTES=$(du -sk "$SRC" | awk '{print $1*1024}')
SRC_HUMAN=$(du -sh "$SRC" | awk '{print $1}')
echo "Source: $SRC ($SRC_HUMAN, $SRC_BYTES bytes)"
echo "Output: $OUTPUT"
echo "Level:  -$LEVEL"
```

### Step 3 — Build exclude args

```bash
# Caller passes excludes; example accumulator:
#   EXCLUDES+=( -x '*.log' )
#   EXCLUDES+=( -x 'node_modules/*' )
EXCLUDES=("${EXCLUDES[@]:-}")
```

### Step 4 — Zip it

```bash
# -r recurse; -q quiet; -<N> compression; -x at the END
zip -r "-$LEVEL" -q "$OUTPUT" "$SRC" "${EXCLUDES[@]}"
RC=$?
if [ $RC -ne 0 ] || [ ! -f "$OUTPUT" ]; then
  echo "ERROR: zip failed (rc=$RC)"
  exit 1
fi
```

### Step 5 — Report

```bash
OUT_BYTES=$(wc -c < "$OUTPUT" | tr -d ' ')
OUT_HUMAN=$(du -h "$OUTPUT" | awk '{print $1}')
ENTRIES=$(unzip -l "$OUTPUT" 2>/dev/null | tail -1 | awk '{print $2}')
RATIO=$(python3 -c "print(f'{(1 - $OUT_BYTES/$SRC_BYTES)*100:.1f}')" 2>/dev/null || echo "?")

echo "✅ Zip created"
echo "   Entries:    $ENTRIES"
echo "   Source:     $SRC_HUMAN ($SRC_BYTES bytes)"
echo "   Archive:    $OUT_HUMAN ($OUT_BYTES bytes)"
echo "   Reduction:  ${RATIO}%"
echo "   Path:       $OUTPUT"
```

## Output Contract

```
## Zip create
**Source:**     <abs-path>  (<human>, <bytes>)
**Output:**     <abs-path>  (<human>, <bytes>)
**Entries:**    <N>
**Level:**      0–9 (6 default)
**Reduction:**  XX.X%
**Excludes:**   <patterns or "none">
```

## Gotchas

- **Globs that match dirs**: `--exclude 'node_modules'` does NOT recurse — use `'node_modules/*'` to skip contents. The `zip` man page is unhelpful here; test on a scratch dir first.
- **Excluding dot-files**: `'.git/*'` works; `'.*'` would catch every dot-file at any depth — usually too aggressive.
- **`-r` with single files**: harmless, but verbose. Skip `-r` if `SRC` is a regular file.
- **Symlinks**: zip stores them as symlinks by default. Some unzip implementations (Windows Explorer's built-in!) silently break links into empty files.
- **Encoding**: filenames with non-ASCII chars get UTF-8 in modern zip, but legacy unzip on Windows shows mojibake. Document this if you ship cross-OS releases.
- **Compression level 0**: produces a "stored" zip — useful for archives of already-compressed data (mp4, jpg) where level 6+ wastes CPU.

## Cross-Platform Notes

- **macOS**: `zip` ships built-in (Info-ZIP version).
- **Linux**: `sudo apt install zip` if missing.
- **Windows**: native `tar.exe` can create zips on Win10+. Easier: WSL.
- Verify with `unzip -l output.zip` after creation.
