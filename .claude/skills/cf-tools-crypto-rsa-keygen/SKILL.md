---
name: cf-tools-crypto-rsa-keygen
description: "Generate an RSA keypair via openssl (private PEM + public PEM). Trigger: /cf-tools-crypto-rsa-keygen"
trigger: /cf-tools-crypto-rsa-keygen
version: 1.0.0
---

# /cf-tools-crypto-rsa-keygen

Generate a plain RSA keypair as two PEM files: private key and public key. Use this when you need raw RSA for signing tokens (JWT RS256), encrypting payloads, or integrating with legacy systems. NOT for SSH (use `/cf-tools-crypto-ssh-keygen`) or TLS certs (use `/cf-tools-crypto-openssl-keygen`).

## Usage

```
/cf-tools-crypto-rsa-keygen
/cf-tools-crypto-rsa-keygen --bits 4096 --name jwt-signing
/cf-tools-crypto-rsa-keygen --bits 2048 --output-dir /tmp/keys --passphrase 'optional-pwd'
```

Arguments:
1. `--bits 2048|3072|4096` (optional, default `2048`) — RSA key size
2. `--name STRING` (optional, default `rsa`) — basename for the two output files
3. `--output-dir PATH` (optional, default `./keys`) — output directory
4. `--passphrase STRING` (optional) — encrypt private key with AES-256; empty = unencrypted

## What You Must Do When Invoked

### Step 1 — Validate args + prep output dir

```bash
BITS="${BITS:-2048}"
NAME="${NAME:-rsa}"
OUT_DIR="${OUT_DIR:-./keys}"
PASSPHRASE="${PASSPHRASE:-}"

case "$BITS" in
  2048|3072|4096) ;;
  *) echo "ERROR: --bits must be 2048, 3072, or 4096"; exit 1 ;;
esac

mkdir -p "$OUT_DIR"
PRIV="$OUT_DIR/${NAME}_private.pem"
PUB="$OUT_DIR/${NAME}_public.pem"

if [ -f "$PRIV" ] || [ -f "$PUB" ]; then
  echo "ERROR: $PRIV or $PUB already exists. Choose a different --name or --output-dir."
  exit 1
fi
```

### Step 2 — Generate private key

```bash
if [ -n "$PASSPHRASE" ]; then
  openssl genpkey -algorithm RSA \
    -pkeyopt rsa_keygen_bits:"$BITS" \
    -aes-256-cbc -pass pass:"$PASSPHRASE" \
    -out "$PRIV" 2>/dev/null
else
  openssl genpkey -algorithm RSA \
    -pkeyopt rsa_keygen_bits:"$BITS" \
    -out "$PRIV" 2>/dev/null
fi

chmod 600 "$PRIV"
```

`openssl genpkey` is the modern replacement for `openssl genrsa` (which still works but is deprecated for new code).

### Step 3 — Derive public key

```bash
if [ -n "$PASSPHRASE" ]; then
  openssl rsa -in "$PRIV" -pubout -out "$PUB" -passin pass:"$PASSPHRASE" 2>/dev/null
else
  openssl rsa -in "$PRIV" -pubout -out "$PUB" 2>/dev/null
fi

chmod 644 "$PUB"
```

### Step 4 — Sanity-check + fingerprint

```bash
# Verify pair matches
PRIV_MOD=$(openssl rsa -in "$PRIV" $([ -n "$PASSPHRASE" ] && echo "-passin pass:$PASSPHRASE") -modulus -noout 2>/dev/null | openssl sha256 | awk '{print $NF}')
PUB_MOD=$(openssl rsa -in "$PUB" -pubin -modulus -noout 2>/dev/null | openssl sha256 | awk '{print $NF}')

if [ "$PRIV_MOD" != "$PUB_MOD" ]; then
  echo "ERROR: modulus mismatch — key derivation failed"
  exit 1
fi

# Fingerprint (DER-encoded SPKI hash, same as JWK thumbprint flavor)
FP=$(openssl rsa -in "$PUB" -pubin -outform DER 2>/dev/null | openssl sha256 | awk '{print $NF}')
```

NEVER print the contents of the private key file in skill output.

## Output Contract

```
## RSA keypair generated

**Key size:**     <bits>-bit
**Private key:**  <path>  (chmod 600 — DO NOT SHARE)
                  Encryption: AES-256 with passphrase | unencrypted
**Public key:**   <path>  (safe to share)
**Fingerprint:**  SHA256 <hex>  (DER-SPKI)
**Pair match:**   ✅ private and public moduli match

### Public key (copy to JWT verifier, OAuth client, etc.)

<contents of public PEM>

⚠️ Private key saved to <path>. Never commit it. Add `*.pem` and `*/keys/` to .gitignore.
```

## Gotchas

- **2048 vs 4096**: 2048 is fine for everything pre-2030. 4096 ~4× slower to generate, ~3× slower per RSA op. Don't go below 2048 — 1024 is broken.
- **Unencrypted private keys**: necessary for services that auto-start (nginx, app servers). Compensate with filesystem permissions (chmod 600 + restricted user).
- **PKCS#1 vs PKCS#8 PEM**: `openssl genpkey` produces PKCS#8 (`-----BEGIN PRIVATE KEY-----`). Some legacy code wants PKCS#1 (`-----BEGIN RSA PRIVATE KEY-----`). Convert: `openssl rsa -in priv.pem -traditional -out priv-pkcs1.pem`.
- **Public key format**: this skill outputs SPKI PEM (`-----BEGIN PUBLIC KEY-----`). For SSH public-key format, use `ssh-keygen -y -f priv.pem`. For PKCS#1: `openssl rsa -RSAPublicKey_out -in priv.pem`.
- **JWT RS256 signing**: this key works directly. Private key signs, public key verifies.
- **Encrypting data directly with RSA**: don't. RSA can only encrypt payloads smaller than the key. Use RSA-OAEP to wrap an AES key, then AES-GCM the payload.

## Cross-Platform Notes

- **macOS LibreSSL vs OpenSSL**: `/usr/bin/openssl` on mac is LibreSSL. `brew install openssl` provides upstream OpenSSL at `/opt/homebrew/opt/openssl/bin/openssl`. Both work for keygen.
- **OpenSSL 1.1 vs 3.x**: `genpkey` works on both. `genrsa` still works as a fallback.
- **Air-gapped boxes**: this is offline-safe — no network calls.
