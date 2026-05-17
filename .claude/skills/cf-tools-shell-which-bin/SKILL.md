---
name: cf-tools-shell-which-bin
description: "Locate a binary on PATH with resolved real path, version, and brew/path provenance. Trigger: /cf-tools-shell-which-bin"
trigger: /cf-tools-shell-which-bin
version: 1.0.0
---

# /cf-tools-shell-which-bin

Resolve a binary name to its full provenance: which path the shell will pick first, where that path actually points (following symlinks), the version it reports, and the package manager that installed it.

Solves the "I have three pythons installed, which one am I actually running?" problem.

## Usage

```
/cf-tools-shell-which-bin python3
/cf-tools-shell-which-bin node
/cf-tools-shell-which-bin --all openssl       # show every match on PATH, not just first
/cf-tools-shell-which-bin --version-flag -V git  # try custom version flag if --version fails
```

Arguments:
1. `name` (required) — binary name to look up
2. `--all` (optional flag) — show every match on PATH (like `which -a`)
3. `--version-flag STRING` (optional, default tries `--version`, `-V`, `-v`) — version flag

## What You Must Do When Invoked

### Step 1 — First match on PATH

```bash
NAME="<arg1>"
FIRST=$(command -v "$NAME" 2>/dev/null)

if [ -z "$FIRST" ]; then
  echo "❌ '$NAME' not found on PATH"
  echo ""
  echo "PATH = $PATH"
  exit 1
fi
```

### Step 2 — Resolve symlinks

```bash
REAL=$(readlink -f "$FIRST" 2>/dev/null || python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$FIRST")
```

macOS `readlink -f` exists in coreutils-but-not-system. Fall back to python3.

### Step 3 — Try to get version

```bash
get_version() {
  local bin="$1"
  for flag in --version -V -v -version; do
    OUT=$("$bin" $flag 2>&1 | head -3 | tr '\n' ' ' | sed 's/  */ /g')
    if [ -n "$OUT" ] && ! echo "$OUT" | grep -qi "unknown\|invalid\|usage:"; then
      echo "$OUT"
      return
    fi
  done
  echo "(no version reported)"
}
VERSION=$(get_version "$REAL")
```

### Step 4 — Determine provenance

```bash
provenance() {
  local path="$1"
  case "$path" in
    /opt/homebrew/*|/usr/local/Cellar/*|/usr/local/opt/*)
      echo "Homebrew ($(brew list --formula --versions 2>/dev/null | grep -E "^$NAME " | head -1))"
      ;;
    */node_modules/.bin/*) echo "npm (node_modules/.bin)" ;;
    */\.cargo/bin/*)       echo "Cargo" ;;
    */\.pyenv/*)           echo "pyenv" ;;
    */\.rbenv/*)           echo "rbenv" ;;
    */\.nvm/*)             echo "nvm" ;;
    */\.asdf/*)            echo "asdf" ;;
    /usr/bin/*)            echo "macOS / system" ;;
    /bin/*|/sbin/*)        echo "system core" ;;
    *)                     echo "custom / unknown" ;;
  esac
}
PROV=$(provenance "$REAL")
```

### Step 5 — Optional: --all enumeration

```bash
if [ "$ALL" = "1" ]; then
  echo "All matches on PATH:"
  # which -a equivalent, portable
  echo "$PATH" | tr ':' '\n' | while IFS= read -r dir; do
    [ -x "$dir/$NAME" ] && echo "  $dir/$NAME"
  done
fi
```

## Output Contract

```
## Binary lookup: <name>

**On PATH:**     <first match>
**Real path:**   <resolved path>  (if different from On PATH)
**Provenance:**  Homebrew (foo 1.2.3) | npm | system | pyenv | …
**Version:**     <first line of --version output>

### Symlink chain (if any)
  /usr/local/bin/<name>
  → /opt/homebrew/opt/<name>/bin/<name>
  → /opt/homebrew/Cellar/<name>/1.2.3/bin/<name>

### Other matches on PATH (with --all)
  /usr/bin/<name>
  /opt/homebrew/bin/<name>
```

## Gotchas

- **Shell builtins shadow binaries**: `command -v cd` returns "cd (built-in)". `which cd` may differ. This skill uses `command -v` for accuracy.
- **Aliases mask real binaries**: `which ls` may report `aliased to ls -G`. The skill ignores aliases — pass `\ls` to bypass.
- **`readlink -f` differs across platforms**: GNU coreutils on Linux has it; macOS BSD readlink does not (use Python fallback or `brew install coreutils` for `greadlink`).
- **Version flag varies**: most use `--version`. `java` uses `-version` (stderr). `go` uses `version`. Pass `--version-flag` when needed.
- **pyenv/nvm shims**: the "real path" is a shim that re-exec's the real binary via the version manager. Run `pyenv which python3` for the bottom-of-stack.
- **PATH order matters**: `command -v` returns the first match. Order PATH carefully — `/opt/homebrew/bin` before `/usr/bin` typically.

## Cross-Platform Notes

- **macOS**: BSD `readlink` lacks `-f`. Use Python fallback or `brew install coreutils`.
- **Linux**: `readlink -f` and `which -a` work as expected.
- **WSL**: `which` on Windows-side binaries (`/mnt/c/...`) works but version flags may misbehave.
