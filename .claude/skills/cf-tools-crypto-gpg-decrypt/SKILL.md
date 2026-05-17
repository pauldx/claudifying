---
name: cf-tools-crypto-gpg-decrypt
description: "Decrypt a GPG-encrypted file or stdin with your private key. Trigger: /cf-tools-crypto-gpg-decrypt"
trigger: /cf-tools-crypto-gpg-decrypt
version: 1.0.0
---

# /cf-tools-crypto-gpg-decrypt

Decrypt a `.gpg` or `.asc` file using your private key (which must be in your keyring). Handles both binary and ascii-armored ciphertext — GPG auto-detects.

## Prerequisites

```bash
command -v gpg >/dev/null || { echo "ERROR: gpg not installed. brew install gnupg"; exit 1; }
gpg --list-secret-keys | grep -q . || { echo "ERROR: no private key in keyring. Import yours with: gpg --import private.asc"; exit 1; }
```

## Usage

```
/cf-tools-crypto-gpg-decrypt --input secret.gpg
/cf-tools-crypto-gpg-decrypt --input secret.gpg --output recovered.txt
/cf-tools-crypto-gpg-decrypt --input secret.asc --stdout
cat secret.gpg | /cf-tools-crypto-gpg-decrypt --stdout
```

Arguments:
1. `--input PATH` (optional) — encrypted file; reads stdin if omitted
2. `--output PATH` (optional, default `<input>` with `.gpg`/`.asc` stripped) — plaintext output path
3. `--stdout` (optional flag) — write plaintext to stdout instead of a file

## What You Must Do When Invoked

### Step 1 — Validate input

```bash
INPUT="${INPUT:--}"
if [ "$INPUT" != "-" ] && [ ! -f "$INPUT" ]; then
  echo "ERROR: encrypted file not found: $INPUT"
  exit 1
fi
```

### Step 2 — Determine output target

```bash
if [ "$STDOUT" = "1" ]; then
  OUT_TARGET="-"
elif [ -z "$OUTPUT" ]; then
  # Strip .gpg / .asc extension
  case "$INPUT" in
    *.gpg) OUTPUT="${INPUT%.gpg}" ;;
    *.asc) OUTPUT="${INPUT%.asc}" ;;
    *)     OUTPUT="${INPUT}.decrypted" ;;
  esac
  OUT_TARGET="$OUTPUT"
else
  OUT_TARGET="$OUTPUT"
fi
```

### Step 3 — Decrypt

```bash
if [ "$INPUT" = "-" ]; then
  if [ "$OUT_TARGET" = "-" ]; then
    gpg --decrypt --quiet
  else
    gpg --decrypt --quiet --output "$OUT_TARGET" --yes
  fi
else
  if [ "$OUT_TARGET" = "-" ]; then
    gpg --decrypt --quiet "$INPUT"
  else
    gpg --decrypt --quiet --output "$OUT_TARGET" --yes "$INPUT"
  fi
fi
```

GPG will prompt for the private-key passphrase via pinentry (terminal or GUI agent).

### Step 4 — Identify signing key (if signed)

If the ciphertext was also signed, GPG's stderr shows the signer. Capture it and report:

```bash
SIGNER=$(gpg --decrypt --quiet "$INPUT" 2>&1 >/dev/null | grep -i "Good signature" | head -1)
```

## Output Contract

```
## GPG decryption complete

**Input:**     <path | stdin>
**Output:**    <path | stdout>
**Bytes:**     <count>
**Signature:** none | Good signature from "<name> <email>" | BAD signature ⚠️
```

If decryption fails, surface gpg's stderr verbatim — the user needs to see "No secret key" or "decryption failed: Bad session key" to diagnose.

## Gotchas

- **"decryption failed: No secret key"**: you don't have the matching private key. The file was encrypted to someone else's public key.
- **Pinentry prompt vanishes in non-interactive contexts**: pre-load the passphrase into gpg-agent via `gpg --batch --passphrase-file /path -d ...` for scripting.
- **`.asc` vs `.gpg`**: GPG handles both — no need to differentiate at the call site.
- **Stripped extension creates conflict**: if `secret.gpg` → `secret` already exists, `--yes` overwrites it. Pass explicit `--output` if you care.
- **BAD signature warning**: even if decryption succeeds, a BAD signature means the file was modified after signing. Treat the plaintext as untrusted.

## Cross-Platform Notes

- **macOS**: pinentry-mac via `brew install pinentry-mac` + `~/.gnupg/gpg-agent.conf` → `pinentry-program /usr/local/bin/pinentry-mac`.
- **Linux**: pinentry-curses (terminal) or pinentry-gtk2 (desktop).
- **Headless / CI**: set `--pinentry-mode loopback --passphrase "$PASSPHRASE"` and pipe the passphrase via env var or `--passphrase-file`.
