---
name: cf-tools-archive-zip-extract
description: "List or extract a .zip archive with default list-only mode and path-traversal protection. Trigger: /cf-tools-archive-zip-extract"
trigger: /cf-tools-archive-zip-extract
version: 1.0.0
---

# /cf-tools-archive-zip-extract

Inspect or unpack a `.zip`. Like the tar-extract skill, the **default mode is list-only** (`unzip -l`). The user must pass `--extract` to actually unpack — protecting against zip-bombs and surprise top-level layouts.

## Usage

```
/cf-tools-archive-zip-extract release.zip                     # list only (default)
/cf-tools-archive-zip-extract release.zip --extract           # extract into cwd
/cf-tools-archive-zip-extract release.zip --extract --to /tmp/release
/cf-tools-archive-zip-extract release.zip --list              # explicit list
```

Arguments:
1. `archive` (required) — `.zip` path
2. `--extract` — actually extract
3. `--list` — explicit list mode (default)
4. `--to <dir>` — destination (default cwd)

## What You Must Do When Invoked

### Step 1 — Validate

```bash
ARCHIVE="$1"
[ -f "$ARCHIVE" ] || { echo "ERROR: archive not found: $ARCHIVE"; exit 1; }

if ! command -v unzip >/dev/null 2>&1; then
  echo "ERROR: unzip not installed. macOS: built-in. Linux: sudo apt install unzip"
  exit 2
fi

case "$ARCHIVE" in
  *.zip|*.ZIP) ;;
  *) echo "ERROR: not a .zip extension: $ARCHIVE"; exit 1 ;;
esac
```

### Step 2 — Path-traversal safety check

```bash
# Get entry list without extracting, then guard
ENTRIES=$(unzip -Z1 "$ARCHIVE")
BAD=$(echo "$ENTRIES" | awk '/^\// || /(^|\/)\.\.(\/|$)/ { print }')

if [ -n "$BAD" ]; then
  echo "ERROR: archive contains unsafe entries (path traversal or absolute paths):"
  echo "$BAD" | head -10
  echo "Refusing to extract. Inspect with: unzip -l \"$ARCHIVE\""
  exit 1
fi
COUNT=$(echo "$ENTRIES" | wc -l | tr -d ' ')
echo "Archive: $ARCHIVE  ($COUNT entries, safety check passed)"
```

### Step 3 — List or extract

```bash
MODE="${MODE:-list}"
DEST="${DEST:-.}"

if [ "$MODE" = "list" ]; then
  unzip -l "$ARCHIVE" | head -250
  if [ "$COUNT" -gt 250 ]; then
    echo "... (250 of $COUNT shown — pass --extract to unpack)"
  fi
  exit 0
fi

mkdir -p "$DEST"
echo "Extracting to: $DEST"
# -o overwrite without prompting; -q quiet (per-file output kept short)
unzip -oq "$ARCHIVE" -d "$DEST"
```

### Step 4 — Report

```bash
echo "✅ Extracted $COUNT entries to $DEST"
echo "   Size: $(du -sh "$DEST" | awk '{print $1}')"
```

## Output Contract

```
## Zip extract
**Archive:**     <abs-path>
**Mode:**        list | extract
**Destination:** <abs-path>  (only if extracting)
**Entries:**     <N>
**Total size:**  <human-readable>  (only if extracting)
```

## Gotchas

- **DEFAULT IS LIST-ONLY**: matches the tar-extract sibling skill. Document this prominently — users coming from Finder/Explorer expect double-click semantics.
- **Path traversal**: `..` or absolute paths in entries → refuse. The check uses awk, so it handles `dir/../escape` and `/etc/passwd` patterns.
- **Zip-bomb defense**: this skill does NOT measure decompressed size before extracting. For untrusted archives, run `unzip -l` first and verify the "Total" line doesn't blow up disk.
- **macOS Archive Utility quirks**: archives created by Finder may have `__MACOSX/` and `.DS_Store` cruft. Mention `find … -name __MACOSX -prune` if user wants cleanup.
- **Filename encoding**: Windows-created zips with cp437 or cp932 names show as mojibake on Unix. `unzip -O <encoding>` can fix; default tries UTF-8.
- **Overwriting existing files**: `-o` overwrites silently. If user wants confirmations, drop `-o`.

## Cross-Platform Notes

- **macOS / Linux**: `unzip` is the Info-ZIP tool; same flags.
- **Windows**: PowerShell `Expand-Archive` is the native option, but flag mapping is different. WSL is easier.
- Verify install: `unzip -v | head -1` should print version.
