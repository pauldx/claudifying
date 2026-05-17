---
name: cf-tools-hash-sha256
description: "SHA-256 of file or stdin; verify against a known hash or sidecar .sha256. Trigger: /cf-tools-hash-sha256"
trigger: /cf-tools-hash-sha256
version: 1.0.0
---

# /cf-tools-hash-sha256

Compute SHA-256 for one or more files, or for stdin. Supports verifying against a known hash string or a sidecar `*.sha256` file. Common use: confirming a downloaded artifact matches the publisher's hash.

## Usage

```
/cf-tools-hash-sha256 <file> [<file> ...]
echo -n "hello world" | /cf-tools-hash-sha256 -          # stdin

/cf-tools-hash-sha256 <file> --check <hash>              # compare to literal
/cf-tools-hash-sha256 <file> --check                     # compare to file.sha256
/cf-tools-hash-sha256 <file> --write                     # write file.sha256 sidecar
```

Arguments:
1. One or more file paths, or `-` for stdin
2. `--check [<hash>]` — verify mode; without value, reads sidecar `<file>.sha256`
3. `--write` — write a sidecar `<file>.sha256` next to each input

## What You Must Do When Invoked

### Step 1 — Identify the right hashing tool

```bash
if command -v shasum >/dev/null 2>&1; then
  HASH="shasum -a 256"     # macOS, BSDs
elif command -v sha256sum >/dev/null 2>&1; then
  HASH="sha256sum"         # GNU coreutils
else
  echo "ERROR: no sha256 tool found" >&2
  exit 1
fi
```

### Step 2 — Parse mode

```bash
FILES=()
MODE="hash"   # hash | check | write
EXPECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check)
      MODE="check"
      # peek next arg — if it looks like a 64-hex hash, it's the literal
      if [ -n "$2" ] && echo "$2" | grep -qE '^[a-fA-F0-9]{64}$'; then
        EXPECT="$2"; shift
      fi
      ;;
    --write) MODE="write" ;;
    -*) echo "ERROR: unknown flag $1" >&2; exit 1 ;;
    *)  FILES+=("$1") ;;
  esac
  shift
done
```

### Step 3 — Compute / compare per file

```bash
fail=0
for f in "${FILES[@]}"; do
  if [ "$f" = "-" ]; then
    GOT=$($HASH | awk '{print $1}')
    NAME="(stdin)"
  else
    if [ ! -f "$f" ]; then
      echo "ERROR: not a file: $f" >&2; fail=1; continue
    fi
    GOT=$($HASH "$f" | awk '{print $1}')
    NAME="$f"
  fi

  case "$MODE" in
    hash)
      echo "$GOT  $NAME"
      ;;
    write)
      echo "$GOT  $(basename "$f")" > "${f}.sha256"
      echo "wrote ${f}.sha256"
      ;;
    check)
      if [ -z "$EXPECT" ]; then
        if [ ! -f "${f}.sha256" ]; then
          echo "ERROR: ${f}.sha256 not found" >&2; fail=1; continue
        fi
        EXP_FILE=$(awk '{print $1}' "${f}.sha256")
      else
        EXP_FILE="$EXPECT"
      fi
      if [ "$GOT" = "$EXP_FILE" ]; then
        echo "✅ OK   $NAME"
      else
        echo "❌ FAIL $NAME"
        echo "   expected: $EXP_FILE"
        echo "   got:      $GOT"
        fail=1
      fi
      ;;
  esac
done
exit $fail
```

## Output Contract

Plain mode:
```
b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9  hello.txt
```

Check mode:
```
✅ OK   hello.txt
❌ FAIL bad.txt
   expected: deadbeef...
   got:      cafebabe...
```

Write mode:
```
wrote hello.txt.sha256
```

## Gotchas

- **`shasum` on macOS vs `sha256sum` on Linux** print the same format but live in different places — always feature-detect. Don't hardcode either.
- **Trailing newlines in stdin** change the hash. `echo "hello"` ≠ `echo -n "hello"`. Document the difference.
- **Case sensitivity of hex** — accept both upper and lower in `--check` comparison; this skill lowercases by relying on the tool's lowercase output but the user may paste uppercase. Normalize:
  ```bash
  EXP_FILE=$(echo "$EXP_FILE" | tr 'A-F' 'a-f')
  GOT=$(echo "$GOT" | tr 'A-F' 'a-f')
  ```
- **Sidecar format** — `<hash>  <basename>`. Two spaces. `shasum -c` is finicky about the separator.
- **Binary vs text mode**: on Windows, GNU `sha256sum` distinguishes `*` (binary) and ` ` (text) prefix on filename. macOS `shasum` always treats binary. Don't normalize across — just store as the tool emits.
- **Large files**: SHA-256 is CPU-bound; ~500 MB/s on modern x86. For multi-GB files, no progress bar — warn the user it may take a minute.

## Cross-Platform Notes

- **macOS**: `/usr/bin/shasum -a 256`. `/sbin/sha256sum` is also present in recent macOS.
- **Linux**: `sha256sum` from coreutils.
- **Windows**: PowerShell `Get-FileHash -Algorithm SHA256 <file>`. Not handled by this skill — recommend WSL.
- **OpenSSL fallback**: `openssl dgst -sha256 <file>` also works but output format differs (`SHA256(file)= hash`); avoid unless both shasum and sha256sum are absent.
