---
name: cf-tools-system-env-dump
description: "Dump environment variables with optional masking of secret-shaped keys (token, secret, key, password, api, auth). Trigger: /cf-tools-system-env-dump"
trigger: /cf-tools-system-env-dump
version: 1.0.0
---

# /cf-tools-system-env-dump

Print the current process's environment variables, sorted, one per line. With
`--sensitive`, any key matching `(token|secret|key|password|api|auth)`
case-insensitively gets its value replaced by `***REDACTED***` so the output
can be safely pasted into bug reports.

## Usage

```
/cf-tools-system-env-dump                       # all vars, raw
/cf-tools-system-env-dump --sensitive           # mask secret-shaped vars
/cf-tools-system-env-dump --sensitive --grep PATH    # filter to matching keys
```

Arguments:
- `--sensitive` (optional flag) — redact secret-looking values
- `--grep <pattern>` (optional) — only show keys matching the pattern (regex)

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
MASK=0
PATTERN=""
prev=""
for arg in "$@"; do
  [ "$arg" = "--sensitive" ] && MASK=1
  [ "$prev" = "--grep" ]     && PATTERN="$arg"
  prev="$arg"
done
```

### Step 2 — Dump and process

```bash
python3 - "$MASK" "$PATTERN" <<'PY'
import os, re, sys
mask    = sys.argv[1] == "1"
pattern = sys.argv[2]
SECRET_RE = re.compile(r"(?i)(token|secret|key|password|api|auth)")

keys = sorted(os.environ.keys())
if pattern:
    try:
        rx = re.compile(pattern)
        keys = [k for k in keys if rx.search(k)]
    except re.error as e:
        print(f"ERROR: invalid --grep regex: {e}", file=sys.stderr)
        sys.exit(1)

redacted_count = 0
for k in keys:
    v = os.environ[k]
    if mask and SECRET_RE.search(k):
        v = "***REDACTED***"
        redacted_count += 1
    print(f"{k}={v}")

print(f"\n# {len(keys)} variable(s) shown", file=sys.stderr)
if mask:
    print(f"# {redacted_count} value(s) redacted (--sensitive matched: token|secret|key|password|api|auth)", file=sys.stderr)
PY
```

## Output Contract

```
## Environment dump

```
HOME=/Users/example
PATH=/usr/local/bin:/usr/bin:/bin
GITHUB_TOKEN=***REDACTED***
AWS_ACCESS_KEY_ID=***REDACTED***
LANG=en_US.UTF-8
```

**Variables shown:** <count>
**Redacted:**         <count> (via --sensitive)
**Filter:**           --grep "<pattern>" | (none)
```

## Gotchas

- **Subshell environment ≠ login shell** — if Claude Code launches this in a
  non-login shell, vars from `~/.zprofile` / `~/.bashrc` may be missing. Run
  `source ~/.zshrc && /cf-tools-system-env-dump` if expected vars are absent.
- **`SSH_AUTH_SOCK`, `XPC_SERVICE_NAME`, `__CFBundleIdentifier`** — system-set
  vars are intentionally included. They reveal less than secret keys but tell
  you which app launched the shell.
- **The regex matches substrings, not whole words** — `MONKEY=banana` gets
  redacted because `KEY` matches `(?i)key`. False positives are safer than
  false negatives in this skill.
- **`--grep` is regex, not glob** — use `--grep 'AWS_'` not `--grep 'AWS_*'`.
- **Multi-line values** — env vars with embedded newlines (`$'\n'`) will look
  like multiple key=value lines. Rare in practice but check formatting if a
  value looks split.
- **Even without `--sensitive`, treat the output as sensitive by default** —
  it likely contains `PATH`, hostnames, and project paths.

## Cross-Platform Notes

- **macOS / Linux**: `os.environ` reflects the process environ. Works
  identically.
- **Windows / PowerShell**: would need `$env:` enumeration; this skill targets
  POSIX-like shells. WSL works.
