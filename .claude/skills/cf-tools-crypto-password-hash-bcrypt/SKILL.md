---
name: cf-tools-crypto-password-hash-bcrypt
description: "Hash or verify a password using bcrypt (cost factor 12 default). Trigger: /cf-tools-crypto-password-hash-bcrypt"
trigger: /cf-tools-crypto-password-hash-bcrypt
version: 1.0.0
---

# /cf-tools-crypto-password-hash-bcrypt

Generate a bcrypt hash of a password (for seeding test users, populating fixtures, comparing implementations), or verify a candidate password against an existing bcrypt hash.

bcrypt remains the safe default for password storage in 2026: adaptive cost factor, built-in salt, slow-by-design. (Argon2id is also fine; bcrypt is more ubiquitous across language ecosystems.)

## Prerequisites

```bash
python3 -c "import bcrypt" 2>&1 | grep -q "ModuleNotFoundError" && {
  echo "Installing bcrypt..."
  pip3 install --user bcrypt || pip3 install --break-system-packages --user bcrypt
}
```

If the install fails (PEP 668 / externally-managed environment), use a venv:

```bash
python3 -m venv /tmp/bcrypt-venv
/tmp/bcrypt-venv/bin/pip install bcrypt
PYTHON=/tmp/bcrypt-venv/bin/python
```

Alternative: install [`bcrypt-tool`](https://github.com/bitnami-labs/bcrypt-cli) Go binary if you want a no-Python option.

## Usage

```
/cf-tools-crypto-password-hash-bcrypt --password 'hunter2'
/cf-tools-crypto-password-hash-bcrypt --password 'hunter2' --cost 14
/cf-tools-crypto-password-hash-bcrypt --check --password 'hunter2' --hash '$2b$12$abc...'
echo -n 'hunter2' | /cf-tools-crypto-password-hash-bcrypt --stdin
```

Arguments:
1. `--password STRING` (required unless `--stdin`) — password to hash or verify
2. `--stdin` (optional flag) — read password from stdin (more secure than CLI arg)
3. `--cost N` (optional, default `12`) — bcrypt cost factor (4–17; 12 is the 2026 sweet spot)
4. `--check` (optional flag) — verify mode: requires `--password` and `--hash`
5. `--hash STRING` (verify mode only) — existing bcrypt hash to compare against

## What You Must Do When Invoked

### Step 1 — Prereq check

```bash
PYTHON="${PYTHON:-python3}"
$PYTHON -c "import bcrypt" 2>/dev/null || {
  echo "bcrypt not installed for $PYTHON. Run:"
  echo "  pip3 install --user bcrypt"
  echo "  # or, if PEP 668 blocks:"
  echo "  python3 -m venv /tmp/bcrypt-venv && /tmp/bcrypt-venv/bin/pip install bcrypt"
  exit 1
}
```

### Step 2 — Read password (CLI arg or stdin)

```bash
if [ "$STDIN" = "1" ]; then
  read -rs PASSWORD
fi

if [ -z "$PASSWORD" ]; then
  echo "ERROR: --password or --stdin required"
  exit 1
fi
```

### Step 3 — Hash or verify

Hash mode:
```bash
COST="${COST:-12}"
HASH=$($PYTHON - <<PY
import bcrypt, os
pw = os.environ['PASSWORD'].encode('utf-8')
salt = bcrypt.gensalt(rounds=$COST)
print(bcrypt.hashpw(pw, salt).decode('utf-8'))
PY
)
```

Verify mode:
```bash
RESULT=$($PYTHON - <<PY
import bcrypt, os
pw = os.environ['PASSWORD'].encode('utf-8')
hsh = os.environ['HASH'].encode('utf-8')
try:
    print("MATCH" if bcrypt.checkpw(pw, hsh) else "MISMATCH")
except ValueError as e:
    print(f"ERROR: {e}")
PY
)
```

Always pass the password via env var, never via shell argv (argv is visible in `ps`).

### Step 4 — Report

NEVER echo the password back to the user.

## Output Contract

Hash mode:
```
## bcrypt hash generated

**Cost factor:**  12  (≈ 250 ms per check on M1)
**Algorithm:**    $2b$ (bcrypt, modern)
**Hash:**         $2b$12$<22-char-salt><31-char-hash>

Paste into your users table — already includes salt, no separate column needed.
```

Verify mode:
```
## bcrypt verification

**Result:**  ✅ MATCH  | ❌ MISMATCH | 🔴 ERROR: <reason>
```

## Gotchas

- **Cost 12 is the 2026 default**; bump to 13 every couple of years as CPUs get faster. Cost 14+ on a laptop adds 1 s per login.
- **Password truncated at 72 bytes**: bcrypt's hard limit. Pre-hash with SHA-256 if your users may exceed it (e.g., passphrase managers). Note this in your auth code, not here.
- **`$2a$` vs `$2b$` vs `$2y$`**: all compatible. Python's bcrypt emits `$2b$` (correct). PHP emits `$2y$` (historical bug fix, also fine).
- **CLI args leak via `ps`**: prefer `--stdin` for production. The skill warns when `--password` is on the CLI.
- **`bcrypt.checkpw` returns False for malformed hash**: but raises `ValueError` for completely invalid input. Surface the error.
- **PEP 668 (Debian/Ubuntu 23+, macOS Homebrew Python)**: `pip3 install --user bcrypt` may fail with "externally-managed-environment". Use the venv workaround.

## Cross-Platform Notes

- **macOS**: Homebrew Python is PEP-668 protected. Use venv or `pip3 install --break-system-packages --user bcrypt`.
- **Linux**: same — Debian/Ubuntu 23+ are PEP-668 protected; use venv.
- **Windows**: `py -m pip install bcrypt` works without restrictions.
- **No Python at all**: try `htpasswd -bnB <cost> user pass` (Apache utils) for a quick bcrypt hash via the system `htpasswd`.
