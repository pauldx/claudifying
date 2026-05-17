---
name: cf-tools-crypto-gpg-verify
description: "Verify a GPG signature against the original file. Trigger: /cf-tools-crypto-gpg-verify"
trigger: /cf-tools-crypto-gpg-verify
version: 1.0.0
---

# /cf-tools-crypto-gpg-verify

Verify a GPG signature, reporting the signer's identity and whether the file matches the signature. Handles detached (`.sig`/`.asc` + original) and inline (single armored blob) signatures.

## Prerequisites

```bash
command -v gpg >/dev/null || { echo "ERROR: gpg not installed. brew install gnupg"; exit 1; }
# Signer's public key must be in your keyring — import it first if not:
#   gpg --import signer-pubkey.asc
#   gpg --keyserver keys.openpgp.org --recv-keys <KEYID>
```

## Usage

```
/cf-tools-crypto-gpg-verify --signature release.tar.gz.sig --file release.tar.gz
/cf-tools-crypto-gpg-verify --signature release.tar.gz.asc --file release.tar.gz
/cf-tools-crypto-gpg-verify --inline signed-message.asc
```

Arguments:
1. `--signature PATH` (required for detached) — `.sig` or `.asc` signature file
2. `--file PATH` (required for detached) — the original file being signed
3. `--inline PATH` (alternative) — a single inline-signed file containing both content and signature

## What You Must Do When Invoked

### Step 1 — Validate inputs

```bash
if [ -n "$INLINE" ]; then
  [ -f "$INLINE" ] || { echo "ERROR: inline file not found: $INLINE"; exit 1; }
elif [ -n "$SIGNATURE" ] && [ -n "$FILE" ]; then
  [ -f "$SIGNATURE" ] || { echo "ERROR: signature not found: $SIGNATURE"; exit 1; }
  [ -f "$FILE" ] || { echo "ERROR: file not found: $FILE"; exit 1; }
else
  echo "ERROR: pass either --inline PATH, or --signature PATH --file PATH"
  exit 1
fi
```

### Step 2 — Run verification

```bash
# Capture full gpg output (it writes to stderr by design)
if [ -n "$INLINE" ]; then
  OUTPUT=$(gpg --verify "$INLINE" 2>&1)
else
  OUTPUT=$(gpg --verify "$SIGNATURE" "$FILE" 2>&1)
fi
EXIT=$?
```

### Step 3 — Parse signer info

```bash
SIGNER=$(echo "$OUTPUT" | grep -E "Good signature from" | sed 's/.*"\(.*\)".*/\1/' | head -1)
KEYID=$(echo "$OUTPUT" | grep -oE "using [A-Z]+ key [A-F0-9]+" | awk '{print $NF}' | head -1)
DATE=$(echo "$OUTPUT" | grep -E "^gpg: +Signature made" | sed 's/gpg: +Signature made //')

if echo "$OUTPUT" | grep -q "Good signature"; then
  STATUS="GOOD"
elif echo "$OUTPUT" | grep -q "BAD signature"; then
  STATUS="BAD"
elif echo "$OUTPUT" | grep -q "No public key"; then
  STATUS="UNKNOWN_KEY"
elif echo "$OUTPUT" | grep -q "WARNING: This key is not certified"; then
  STATUS="GOOD_UNTRUSTED"
else
  STATUS="ERROR"
fi
```

### Step 4 — Report result

Always show the raw gpg output too — the user needs the exact trust warnings.

## Output Contract

```
## GPG signature verification

**Mode:**       detached | inline
**Signature:**  <path>
**File:**       <path>
**Result:**     ✅ GOOD | ⚠️ GOOD (untrusted) | ❌ BAD | ❓ UNKNOWN_KEY | 🔴 ERROR
**Signer:**     <name> <email>
**Key ID:**     <40-char fingerprint or short ID>
**Signed at:**  <timestamp>

### Raw gpg output

<verbatim gpg stderr>
```

### Status meanings

- **GOOD**: signature matches file AND signer's key is trusted in your web-of-trust.
- **GOOD (untrusted)**: signature matches, but you haven't certified the signer's key. Verify the fingerprint out-of-band and sign their key (`gpg --sign-key <KEYID>`) to remove the warning.
- **BAD**: file was modified after signing OR signature is corrupt. Do NOT trust the file.
- **UNKNOWN_KEY**: you don't have the signer's public key. Import it: `gpg --keyserver keys.openpgp.org --recv-keys <KEYID>`.
- **ERROR**: malformed signature file or gpg error.

## Gotchas

- **"WARNING: This key is not certified"**: signature is mathematically valid; you just haven't told GPG you trust the signer. Not a verification failure.
- **Detached signature without the original file**: GPG can't verify content-free. Pass `--file`.
- **`.asc` mistaken for inline**: ascii-armored detached signatures are still detached — they need the original. Inline armored signatures start with `-----BEGIN PGP SIGNED MESSAGE-----`.
- **Expired key**: signature was valid at the time but key has since expired. GPG warns "key has expired" — judge based on when the signature was made.
- **No newline at end of file**: some web downloads strip trailing newlines and break signatures. Re-download with `curl -o` (not `wget --no-clobber`).

## Cross-Platform Notes

- **macOS / Linux / Windows**: identical `gpg --verify` behavior.
- **Bulk verify multiple files**: `for f in *.tar.gz; do gpg --verify "$f.sig" "$f"; done`.
- **CI/CD**: capture exit code — non-zero means BAD or ERROR. Untrusted-key warnings still exit 0.
