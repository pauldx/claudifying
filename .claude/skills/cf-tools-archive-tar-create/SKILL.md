---
name: cf-tools-archive-tar-create
description: "Create a .tar.gz / .tar.bz2 / .tar.xz archive from a directory with size-before/after report. Trigger: /cf-tools-archive-tar-create"
trigger: /cf-tools-archive-tar-create
version: 1.0.0
---

# /cf-tools-archive-tar-create

Pack a directory into a compressed tar archive. Defaults to gzip; bzip2 and xz available. Reports source size, archive size, and compression ratio.

## Usage

```
/cf-tools-archive-tar-create src/                              # → src.tar.gz
/cf-tools-archive-tar-create src/ backup.tar.gz
/cf-tools-archive-tar-create src/ backup.tar.xz --xz
/cf-tools-archive-tar-create src/ backup.tar.bz2 --bz2
/cf-tools-archive-tar-create src/ backup.tar.gz --exclude '*.log' --exclude 'node_modules'
```

Arguments:
1. `source` (required) — directory or file to archive
2. `output` (optional, default `<basename>.tar.gz`) — archive path; extension implies compression
3. `--gz` (default), `--bz2`, `--xz` — explicit compression
4. `--exclude <pattern>` — pass through to tar's `--exclude` (repeatable)

## What You Must Do When Invoked

### Step 1 — Validate source

```bash
SRC="$1"
[ -e "$SRC" ] || { echo "ERROR: source not found: $SRC"; exit 1; }

OUTPUT="${2:-$(basename "$SRC").tar.gz}"

# Pick compression
case "$OUTPUT" in
  *.tar.gz|*.tgz)   COMPRESS_FLAG="-z" ;;
  *.tar.bz2|*.tbz2) COMPRESS_FLAG="-j" ;;
  *.tar.xz|*.txz)   COMPRESS_FLAG="-J" ;;
  *.tar)            COMPRESS_FLAG="" ;;
  *)                COMPRESS_FLAG="-z"; OUTPUT="${OUTPUT}.tar.gz" ;;
esac

echo "Source:      $SRC"
echo "Output:      $OUTPUT"
echo "Compression: $COMPRESS_FLAG"
```

### Step 2 — Measure source size

```bash
SRC_BYTES=$(du -sk "$SRC" | awk '{print $1*1024}')
SRC_HUMAN=$(du -sh "$SRC" | awk '{print $1}')
echo "Source size: $SRC_HUMAN ($SRC_BYTES bytes)"
```

### Step 3 — Build excludes

```bash
EXCLUDES=()
# Caller appends --exclude flags; example:
#   EXCLUDES+=(--exclude='*.log')
#   EXCLUDES+=(--exclude='node_modules')
```

### Step 4 — Create archive

```bash
# Use -C to archive relative to parent dir; gives clean entries inside
PARENT="$(dirname "$SRC")"
BASE="$(basename "$SRC")"

echo "Archiving..."
if command -v pv >/dev/null 2>&1; then
  # Progress bar via pv
  tar -cf - "${EXCLUDES[@]}" -C "$PARENT" "$BASE" \
    | pv -s "$SRC_BYTES" \
    | case "$COMPRESS_FLAG" in
        "-z") gzip > "$OUTPUT" ;;
        "-j") bzip2 > "$OUTPUT" ;;
        "-J") xz > "$OUTPUT" ;;
        "")   cat > "$OUTPUT" ;;
      esac
else
  tar -c $COMPRESS_FLAG -f "$OUTPUT" "${EXCLUDES[@]}" -C "$PARENT" "$BASE"
fi

[ -f "$OUTPUT" ] || { echo "ERROR: tar failed"; exit 1; }
```

### Step 5 — Report

```bash
OUT_BYTES=$(wc -c < "$OUTPUT" | tr -d ' ')
OUT_HUMAN=$(du -h "$OUTPUT" | awk '{print $1}')
RATIO=$(python3 -c "print(f'{(1 - $OUT_BYTES/$SRC_BYTES)*100:.1f}')" 2>/dev/null || echo "?")

echo "✅ Archive created"
echo "   Source:    $SRC_HUMAN  ($SRC_BYTES bytes)"
echo "   Archive:   $OUT_HUMAN  ($OUT_BYTES bytes)"
echo "   Reduction: ${RATIO}%"
echo "   Path:      $OUTPUT"
```

## Output Contract

```
## Tar create
**Source:**       <abs-path>  (<human>, <bytes>)
**Output:**       <abs-path>  (<human>, <bytes>)
**Compression:**  gzip | bzip2 | xz | none
**Reduction:**    XX.X%
**Excludes:**     <patterns or "none">
```

## Gotchas

- **Absolute path in archive**: tar warns "Removing leading `/`" — by design, prevents archives that overwrite system files on extract. Use `-C` + relative basename.
- **gzip vs xz vs bzip2 tradeoffs**:
  - `gz` — fastest, modest ratio. Default.
  - `bz2` — slower, better ratio, less common.
  - `xz` — slowest, best ratio. Good for releases; avoid for hot-path scripts.
- **`--exclude` ordering**: tar processes `--exclude` left-to-right; put it BEFORE the file list or use the GNU tar style shown above.
- **macOS BSD tar vs GNU tar**: both handle `-z/-j/-J`. macOS does NOT support `--xz` long flag pre-2017; stick to `-J`.
- **Symlinks**: default behavior copies the link, not the target. Use `-h` to dereference (rarely wanted).
- **Permissions / ownership**: preserved by default. Run as root only if you need it; otherwise the user owns extracted files.

## Cross-Platform Notes

- **macOS**: BSD tar (built-in). `pv` is `brew install pv`.
- **Linux**: GNU tar. `pv` via `apt install pv`.
- **Windows**: WSL recommended; native Windows tar (Win10+) works but flag handling is finicky.
