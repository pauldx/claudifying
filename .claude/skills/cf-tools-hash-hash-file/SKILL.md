---
name: cf-tools-hash-hash-file
description: "Multi-algorithm file hashing (md5, sha1, sha256, sha512, blake2). Optional sidecar writer. Trigger: /cf-tools-hash-hash-file"
trigger: /cf-tools-hash-hash-file
version: 1.0.0
---

# /cf-tools-hash-hash-file

Compute one or more hash digests for files using whichever algorithm is requested (or all common ones at once). Optionally writes per-algorithm sidecar files (`file.sha256`, `file.md5`, etc.).

## Usage

```
/cf-tools-hash-hash-file <file> [<file> ...]
/cf-tools-hash-hash-file <file> --algo sha256             # one algo
/cf-tools-hash-hash-file <file> --algo md5,sha1,sha256    # subset
/cf-tools-hash-hash-file <file> --algo all                # md5+sha1+sha256+sha512+blake2b
/cf-tools-hash-hash-file <file> --sidecar                 # write file.<algo> files
```

Arguments:
1. One or more file paths
2. `--algo` (optional, default `sha256`) — comma-separated, or `all`
3. `--sidecar` — also write `*.<algo>` files next to each input

## What You Must Do When Invoked

### Step 1 — Resolve algorithms

```bash
DEFAULT="sha256"
ALGOS="$DEFAULT"
SIDECAR=0
FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --algo)     shift; ALGOS="$1" ;;
    --algo=*)   ALGOS="${1#*=}" ;;
    --sidecar)  SIDECAR=1 ;;
    *)          FILES+=("$1") ;;
  esac
  shift
done

if [ "$ALGOS" = "all" ]; then
  ALGOS="md5,sha1,sha256,sha512,blake2b"
fi
```

### Step 2 — Map algorithm → command (with fallbacks)

| Algo    | macOS                  | Linux (coreutils)   | Fallback                 |
|---------|------------------------|---------------------|--------------------------|
| md5     | `md5 -q`               | `md5sum`            | `openssl dgst -md5`      |
| sha1    | `shasum -a 1`          | `sha1sum`           | `openssl dgst -sha1`     |
| sha256  | `shasum -a 256`        | `sha256sum`         | `openssl dgst -sha256`   |
| sha512  | `shasum -a 512`        | `sha512sum`         | `openssl dgst -sha512`   |
| blake2b | (Homebrew `b2sum`)     | `b2sum`             | `openssl dgst -blake2b512` |

```bash
hash_one() {
  local algo="$1" f="$2"
  case "$algo" in
    md5)
      if   command -v md5sum >/dev/null;  then md5sum "$f"   | awk '{print $1}'
      elif command -v md5 >/dev/null;     then md5 -q "$f"
      else openssl dgst -md5    "$f" | awk '{print $NF}'
      fi ;;
    sha1)
      if   command -v sha1sum >/dev/null; then sha1sum "$f"  | awk '{print $1}'
      elif command -v shasum  >/dev/null; then shasum -a 1   "$f" | awk '{print $1}'
      else openssl dgst -sha1   "$f" | awk '{print $NF}'
      fi ;;
    sha256)
      if   command -v sha256sum >/dev/null; then sha256sum "$f" | awk '{print $1}'
      elif command -v shasum    >/dev/null; then shasum -a 256 "$f" | awk '{print $1}'
      else openssl dgst -sha256 "$f" | awk '{print $NF}'
      fi ;;
    sha512)
      if   command -v sha512sum >/dev/null; then sha512sum "$f" | awk '{print $1}'
      elif command -v shasum    >/dev/null; then shasum -a 512 "$f" | awk '{print $1}'
      else openssl dgst -sha512 "$f" | awk '{print $NF}'
      fi ;;
    blake2b)
      if   command -v b2sum >/dev/null; then b2sum "$f" | awk '{print $1}'
      else openssl dgst -blake2b512 "$f" | awk '{print $NF}'
      fi ;;
    *) echo "ERROR: unknown algo $algo" >&2; return 1 ;;
  esac
}
```

### Step 3 — Loop files × algorithms

```bash
IFS=',' read -ra A_ARR <<< "$ALGOS"

for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: not a file: $f" >&2; continue
  fi
  echo "# $f"
  for a in "${A_ARR[@]}"; do
    H=$(hash_one "$a" "$f")
    printf "%-8s %s\n" "$a" "$H"
    if [ "$SIDECAR" -eq 1 ]; then
      echo "$H  $(basename "$f")" > "${f}.${a}"
      echo "         → wrote ${f}.${a}"
    fi
  done
  echo ""
done
```

## Output Contract

```
# release.tar.gz
md5      e8d8c7a1b2...
sha1     6d3f9a...
sha256   b94d27b9934d...
sha512   8b1a9953c4...
blake2b  786a02f7...
```

With `--sidecar`:
```
sha256   b94d27b9934d...
         → wrote release.tar.gz.sha256
```

## Gotchas

- **MD5 and SHA-1 are broken for security** — do not use to verify integrity of attacker-controlled artifacts. Still fine as cheap content-addressing for cache busting. The skill should print a warning when both are requested together for a security context (out of scope to auto-detect).
- **`blake2b` defaults to 512-bit output everywhere** here. Truncated variants (blake2b-256) exist but are uncommon — avoid surprising users with them.
- **`openssl dgst` output format**: `MD5(file)= deadbeef...` — the parser awks `$NF` to get just the hex.
- **Sidecar naming**: `file.tar.gz.sha256`, NOT `file.tar.gz.tar.gz.sha256`. Append once.
- **Locking during writes** — concurrent invocation on the same path can corrupt sidecars. Not worth fixing for ad-hoc use.
- **`b2sum` is not always installed on macOS** — `brew install coreutils` provides `gb2sum`. The openssl fallback covers everyone.

## Cross-Platform Notes

- **macOS**: `md5`, `shasum` ship in base OS. `b2sum` needs Homebrew coreutils OR uses openssl fallback.
- **Linux**: coreutils provides all but `b2sum` is in newer coreutils (≥ 8.27).
- **Alpine**: `apk add coreutils openssl`.
- **Reproducibility note**: `--sidecar` writes sidecars but does not write a manifest like `SHA256SUMS`. To generate one: `cd dir && sha256sum * > SHA256SUMS` then verify with `sha256sum -c SHA256SUMS`.
