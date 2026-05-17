---
name: cf-tools-crypto-gpg-encrypt
description: "Encrypt a file or stdin to a GPG recipient with optional ascii-armor. Trigger: /cf-tools-crypto-gpg-encrypt"
trigger: /cf-tools-crypto-gpg-encrypt
version: 1.0.0
---

# /cf-tools-crypto-gpg-encrypt

Encrypt data with a recipient's GPG public key. The recipient (and only the recipient) can decrypt with their private key. Supports file or stdin input, binary or ascii-armored output.

## Prerequisites

```bash
command -v gpg >/dev/null || { echo "ERROR: gpg not installed. brew install gnupg"; exit 1; }
gpg --list-keys | grep -q . || { echo "ERROR: no GPG keys in keyring. Import recipient's public key with: gpg --import recipient.asc"; exit 1; }
```

## Usage

```
/cf-tools-crypto-gpg-encrypt --recipient user@example.com --input secret.txt
/cf-tools-crypto-gpg-encrypt --recipient user@example.com --input secret.txt --armor
/cf-tools-crypto-gpg-encrypt --recipient user@example.com --output secret.txt.gpg < plain.txt
cat plain.txt | /cf-tools-crypto-gpg-encrypt --recipient user@example.com --armor
```

Arguments:
1. `--recipient EMAIL_OR_KEYID` (required) — recipient identified by email or 40-char key ID
2. `--input PATH` (optional) — input file; if omitted, reads stdin
3. `--output PATH` (optional, default `<input>.gpg` or `<input>.asc` with --armor) — output path
4. `--armor` (optional flag) — ascii-armored output (safe for email/pasting); default is binary
5. `--trust-model always` (optional flag) — bypass "not certified with a trusted signature" prompt

## What You Must Do When Invoked

### Step 1 — Verify recipient exists in keyring

```bash
RECIPIENT="<from --recipient>"
if ! gpg --list-keys "$RECIPIENT" >/dev/null 2>&1; then
  echo "ERROR: No public key for '$RECIPIENT' in keyring."
  echo "Available keys:"
  gpg --list-keys --keyid-format short | grep -E "^uid|^pub"
  echo ""
  echo "Import the recipient's public key first: gpg --import <recipient>.asc"
  exit 1
fi
```

### Step 2 — Determine output extension

```bash
INPUT="<from --input or - for stdin>"
ARMOR="${ARMOR:-0}"

if [ -z "$OUTPUT" ]; then
  if [ "$INPUT" = "-" ]; then
    OUTPUT="encrypted.$([ $ARMOR = 1 ] && echo asc || echo gpg)"
  else
    OUTPUT="${INPUT}.$([ $ARMOR = 1 ] && echo asc || echo gpg)"
  fi
fi
```

### Step 3 — Encrypt

```bash
FLAGS=(--encrypt --recipient "$RECIPIENT" --output "$OUTPUT" --yes)
[ "$ARMOR" = "1" ] && FLAGS+=(--armor)
[ "$TRUST_ALWAYS" = "1" ] && FLAGS+=(--trust-model always)

if [ "$INPUT" = "-" ]; then
  gpg "${FLAGS[@]}"  # reads stdin
else
  gpg "${FLAGS[@]}" "$INPUT"
fi
```

### Step 4 — Verify and report

```bash
if [ ! -f "$OUTPUT" ] || [ ! -s "$OUTPUT" ]; then
  echo "ERROR: encryption failed — output missing or empty"
  exit 1
fi

BYTES=$(wc -c < "$OUTPUT" | tr -d ' ')
echo "Encrypted → $OUTPUT ($BYTES bytes, $([ $ARMOR = 1 ] && echo ascii-armored || echo binary))"
```

## Output Contract

```
## GPG encryption complete

**Recipient:** <EMAIL or KEYID>  (<fingerprint>)
**Input:**     <path | stdin>
**Output:**    <path>
**Format:**    ascii-armored (.asc) | binary (.gpg)
**Size:**      <bytes>

Only the holder of the matching private key can decrypt this file.
```

## Gotchas

- **"unusable public key"**: the recipient key is expired or revoked. Run `gpg --refresh-keys` or have the recipient send a new one.
- **"no assurance this key belongs to the named user"**: GPG's trust model. Add `--trust-model always` if you've independently verified the fingerprint.
- **Binary `.gpg` over email**: most mail clients mangle binary. Use `--armor` to produce `.asc` you can paste inline.
- **Encrypting to yourself for storage**: use your own email as recipient — you can decrypt later with your private key.
- **Symmetric (password-only) encryption**: this skill is asymmetric only. For password-encrypt-only, use `gpg --symmetric` directly.
- **Stdin without `--output`**: defaults to `encrypted.gpg` in cwd. Pass `--output` explicitly when piping.

## Cross-Platform Notes

- **macOS**: `brew install gnupg`. GUI via GPG Suite.
- **Linux**: `apt install gnupg2` / `dnf install gnupg2`. Already present on most distros.
- **Windows**: Gpg4win installer. Same flags work in PowerShell.
