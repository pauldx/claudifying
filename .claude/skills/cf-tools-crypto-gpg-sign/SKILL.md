---
name: cf-tools-crypto-gpg-sign
description: "Sign a file with your GPG private key — detached or inline, binary or ascii-armored. Trigger: /cf-tools-crypto-gpg-sign"
trigger: /cf-tools-crypto-gpg-sign
version: 1.0.0
---

# /cf-tools-crypto-gpg-sign

Produce a GPG signature proving you authored a file. Detached signatures (`.sig` / `.asc`) live alongside the original — most common for releases and tarballs. Inline signatures wrap the content + signature into a single armored blob.

## Prerequisites

```bash
command -v gpg >/dev/null || { echo "ERROR: gpg not installed. brew install gnupg"; exit 1; }
gpg --list-secret-keys | grep -q . || { echo "ERROR: no secret key in keyring. Generate one: gpg --full-generate-key"; exit 1; }
```

## Usage

```
/cf-tools-crypto-gpg-sign --input release.tar.gz                       # detached binary .sig
/cf-tools-crypto-gpg-sign --input release.tar.gz --armor               # detached ascii .asc
/cf-tools-crypto-gpg-sign --input message.txt --inline --armor         # inline armored
/cf-tools-crypto-gpg-sign --input file --signer me@example.com         # specific key
```

Arguments:
1. `--input PATH` (required) — file to sign
2. `--mode detached|inline` (optional, default `detached`) — signature mode
3. `--armor` (optional flag) — ascii-armored output (`.asc`); default is binary (`.sig`)
4. `--signer EMAIL_OR_KEYID` (optional) — which secret key to sign with (if multiple)
5. `--output PATH` (optional) — override default output path

## What You Must Do When Invoked

### Step 1 — Validate input + signer

```bash
INPUT="<from --input>"
if [ ! -f "$INPUT" ]; then
  echo "ERROR: input file not found: $INPUT"
  exit 1
fi

if [ -n "$SIGNER" ] && ! gpg --list-secret-keys "$SIGNER" >/dev/null 2>&1; then
  echo "ERROR: no secret key matching '$SIGNER'"
  gpg --list-secret-keys --keyid-format short
  exit 1
fi
```

### Step 2 — Pick the right gpg flag

```bash
MODE="${MODE:-detached}"
ARMOR="${ARMOR:-0}"

case "$MODE" in
  detached) FLAG="--detach-sign" ;;
  inline)   FLAG="--sign" ;;
  *) echo "ERROR: --mode must be detached or inline"; exit 1 ;;
esac

ARGS=()
[ "$ARMOR" = "1" ] && ARGS+=(--armor)
[ -n "$SIGNER" ] && ARGS+=(--local-user "$SIGNER")

# Default output extension
if [ -z "$OUTPUT" ]; then
  if [ "$MODE" = "detached" ]; then
    OUTPUT="${INPUT}.$([ $ARMOR = 1 ] && echo asc || echo sig)"
  else
    OUTPUT="${INPUT}.$([ $ARMOR = 1 ] && echo asc || echo gpg)"
  fi
fi
ARGS+=(--output "$OUTPUT" --yes)
```

### Step 3 — Sign

```bash
gpg "${ARGS[@]}" "$FLAG" "$INPUT"
```

### Step 4 — Verify the signature we just produced

```bash
if [ "$MODE" = "detached" ]; then
  gpg --verify "$OUTPUT" "$INPUT" 2>&1 | grep -E "Good signature|BAD"
else
  gpg --verify "$OUTPUT" 2>&1 | grep -E "Good signature|BAD"
fi
```

## Output Contract

```
## GPG signature created

**Input:**       <path>
**Signature:**   <output-path>
**Mode:**        detached | inline
**Format:**      binary (.sig/.gpg) | ascii-armored (.asc)
**Signer:**      <name> <email>  (<key-id>)
**Self-verify:** Good signature ✅ | BAD ⚠️
```

Provide a quickstart verify command for the recipient:

```
To verify:
  gpg --verify <output-path> <input-path>      # detached
  gpg --verify <output-path>                    # inline
```

## Gotchas

- **"signing failed: No secret key"**: no private key in keyring matches the default-key setting. Either generate one or pass `--signer`.
- **Detached vs inline confusion**: detached = two files (original + .sig), inline = one armored blob containing both. Most software distribution uses detached.
- **`.sig` (binary) vs `.asc` (armored)**: GitHub releases accept both. Pick `.asc` if recipients copy-paste from a web page.
- **Multiple secret keys**: GPG signs with `default-key` from `~/.gnupg/gpg.conf`. Force a specific one with `--signer`.
- **Pinentry needed**: signing requires unlocking the private key. Set `--pinentry-mode loopback --passphrase "..."` for headless use.
- **Signature without committed public key**: the recipient must have your public key in their keyring to verify. Publish it: `gpg --armor --export you@example.com`.

## Cross-Platform Notes

- **macOS / Linux**: same `gpg` CLI, identical flags.
- **CI/CD (GitHub Actions)**: use `crazy-max/ghaction-import-gpg` to load a passphrase-protected secret key. Then sign as normal.
- **Git commit signing** uses the same key — `git config user.signingkey <KEYID>` and `git commit -S`.
