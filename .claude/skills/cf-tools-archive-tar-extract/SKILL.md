---
name: cf-tools-archive-tar-extract
description: "Extract or list a tar archive (.tar/.gz/.bz2/.xz) with auto-detect and path-traversal protection. Trigger: /cf-tools-archive-tar-extract"
trigger: /cf-tools-archive-tar-extract
version: 1.0.0
---

# /cf-tools-archive-tar-extract

Auto-detect compression and extract a tar archive. Defaults to LIST-ONLY (`-t`); the user must pass `--extract` to actually unpack — this prevents accidental tarbombs.

## Usage

```
/cf-tools-archive-tar-extract backup.tar.gz                  # list only (default)
/cf-tools-archive-tar-extract backup.tar.gz --extract        # actually extract
/cf-tools-archive-tar-extract backup.tar.gz --extract --to /tmp/restored
/cf-tools-archive-tar-extract backup.tar.xz --list           # explicit list
```

Arguments:
1. `archive` (required) — .tar, .tar.gz/.tgz, .tar.bz2/.tbz2, .tar.xz/.txz
2. `--extract` — actually extract (omit for list-only)
3. `--list` — explicit list mode (default behavior anyway)
4. `--to <dir>` — extraction destination (default: current directory)

## What You Must Do When Invoked

### Step 1 — Validate archive and pick decompression flag

```bash
ARCHIVE="$1"
[ -f "$ARCHIVE" ] || { echo "ERROR: archive not found: $ARCHIVE"; exit 1; }

case "$ARCHIVE" in
  *.tar.gz|*.tgz)   FLAG="-z" ;;
  *.tar.bz2|*.tbz2) FLAG="-j" ;;
  *.tar.xz|*.txz)   FLAG="-J" ;;
  *.tar)            FLAG="" ;;
  *)
    echo "ERROR: unrecognized tar extension: $ARCHIVE"
    echo "Supported: .tar .tar.gz .tgz .tar.bz2 .tbz2 .tar.xz .txz"
    exit 1
    ;;
esac
echo "Archive: $ARCHIVE  (decompress: ${FLAG:-none})"
```

### Step 2 — Validate entries for path traversal BEFORE extracting

```bash
# Always list first and refuse if any entry contains ".." or is absolute
ENTRIES=$(tar -t $FLAG -f "$ARCHIVE")
BAD=$(echo "$ENTRIES" | awk '/^\// || /(^|\/)\.\.(\/|$)/ { print }')

if [ -n "$BAD" ]; then
  echo "ERROR: archive contains unsafe entries (path traversal or absolute paths):"
  echo "$BAD" | head -10
  echo "Refusing to extract. Inspect manually with: tar -t $FLAG -f $ARCHIVE"
  exit 1
fi
COUNT=$(echo "$ENTRIES" | wc -l | tr -d ' ')
echo "Entries: $COUNT (safety check passed)"
```

### Step 3 — List or extract

```bash
MODE="${MODE:-list}"     # caller flips to "extract" via --extract
DEST="${DEST:-.}"

if [ "$MODE" = "list" ]; then
  echo "$ENTRIES" | head -200
  if [ "$COUNT" -gt 200 ]; then
    echo "... (showing 200 of $COUNT — pass --extract to unpack, or pipe full listing yourself)"
  fi
  exit 0
fi

mkdir -p "$DEST"
echo "Extracting to: $DEST"
tar -x $FLAG -f "$ARCHIVE" -C "$DEST"
```

### Step 4 — Report

```bash
echo "✅ Extracted $COUNT entries to $DEST"
echo "   Size: $(du -sh "$DEST" | awk '{print $1}')"
```

## Output Contract

```
## Tar extract
**Archive:**     <abs-path>
**Compression:** gzip | bzip2 | xz | none
**Mode:**        list | extract
**Destination:** <abs-path>  (only if extracting)
**Entries:**     <N>
**Total size:**  <human-readable>  (only if extracting)
```

## Gotchas

- **DEFAULT IS LIST-ONLY**: this is intentional. Many archives have unexpected top-level layouts; preview first. Document this clearly in user-facing help.
- **Path traversal**: entries containing `..` or starting with `/` are refused. Modern GNU tar has `--no-absolute-names` / `--paths-from`, but the explicit check here works on BSD tar too.
- **Symlink attacks**: a malicious archive can include `link -> /etc/passwd`. GNU tar with `--no-overwrite-dir` helps; deeper protection requires a sandbox (out of scope).
- **Auto-detect via extension only**: tar's `-a` flag auto-detects by magic bytes on GNU tar — not on BSD. Sticking to extensions keeps it portable.
- **Listing 100k+ entry archives**: truncate to 200 lines or it floods context. The full listing is one tar command away.
- **Mixed content (multiple top-level dirs)**: list mode reveals this; extraction creates them all in `--to` dir.

## Cross-Platform Notes

- **macOS / Linux / WSL**: same tar invocation works.
- **xz**: BSD tar links against libxz on modern macOS — works out of the box.
- For Windows native tar, prefer WSL — handling of permissions and symlinks is much more sensible.
