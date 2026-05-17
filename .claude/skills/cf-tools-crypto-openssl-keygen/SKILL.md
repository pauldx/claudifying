---
name: cf-tools-crypto-openssl-keygen
description: "Generate a self-signed X.509 certificate + private key with custom CN and SANs. Trigger: /cf-tools-crypto-openssl-keygen"
trigger: /cf-tools-crypto-openssl-keygen
version: 1.0.0
---

# /cf-tools-crypto-openssl-keygen

Generate a self-signed certificate suitable for local HTTPS, internal services, or test environments. Produces a private key + matching cert with the CN and SANs you specify.

Self-signed certs are NOT trusted by browsers without manual install. For public production use, get a real cert from Let's Encrypt or a CA.

## Usage

```
/cf-tools-crypto-openssl-keygen --cn localhost
/cf-tools-crypto-openssl-keygen --cn api.dev.local --san "DNS:api.dev.local,DNS:*.api.dev.local,IP:127.0.0.1" --days 365
/cf-tools-crypto-openssl-keygen --cn test --output-dir /tmp/certs --bits 4096
```

Arguments:
1. `--cn STRING` (required) — Common Name (typically a hostname)
2. `--san STRING` (optional, default `DNS:<cn>`) — Subject Alternative Names, comma-separated `DNS:...,IP:...`
3. `--days N` (optional, default `365`) — validity period
4. `--bits 2048|4096` (optional, default `2048`) — RSA key size
5. `--output-dir PATH` (optional, default `./certs`) — directory for output files
6. `--name STRING` (optional, default `<cn>`) — basename for output files

## What You Must Do When Invoked

### Step 1 — Validate args + prep output dir

```bash
CN="<from --cn>"
SAN="${SAN:-DNS:$CN}"
DAYS="${DAYS:-365}"
BITS="${BITS:-2048}"
OUT_DIR="${OUT_DIR:-./certs}"
NAME="${NAME:-$CN}"

[ -z "$CN" ] && { echo "ERROR: --cn is required"; exit 1; }
mkdir -p "$OUT_DIR"
KEY="$OUT_DIR/${NAME}.key"
CRT="$OUT_DIR/${NAME}.crt"

if [ -f "$KEY" ] || [ -f "$CRT" ]; then
  echo "ERROR: $KEY or $CRT already exists. Choose a different --name or --output-dir."
  exit 1
fi
```

### Step 2 — Generate via single-command openssl req

```bash
openssl req \
  -x509 -newkey rsa:"$BITS" -sha256 \
  -keyout "$KEY" -out "$CRT" \
  -days "$DAYS" -nodes \
  -subj "/CN=$CN" \
  -addext "subjectAltName=$SAN" \
  -addext "keyUsage=digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth,clientAuth" \
  2>&1 | grep -v "^\.\+$"  # filter openssl dot-progress noise

chmod 600 "$KEY"
chmod 644 "$CRT"
```

`-nodes` = "no DES" = private key is NOT password-protected. Necessary for nginx/apache auto-restart. For password-protected keys, drop `-nodes` and add `-passout pass:YOUR_PASS`.

### Step 3 — Inspect generated cert for the report

```bash
SUBJECT=$(openssl x509 -in "$CRT" -noout -subject | sed 's/^subject=//')
ISSUER=$(openssl x509 -in "$CRT" -noout -issuer | sed 's/^issuer=//')
NOT_BEFORE=$(openssl x509 -in "$CRT" -noout -startdate | sed 's/notBefore=//')
NOT_AFTER=$(openssl x509 -in "$CRT" -noout -enddate | sed 's/notAfter=//')
SAN_LIST=$(openssl x509 -in "$CRT" -noout -text | grep -A1 "Subject Alternative Name" | tail -1 | xargs)
FINGERPRINT=$(openssl x509 -in "$CRT" -noout -fingerprint -sha256 | sed 's/SHA256 Fingerprint=//')
```

## Output Contract

```
## Self-signed certificate generated

**CN:**            <cn>
**SAN:**           <comma list>
**Validity:**      <not-before> → <not-after>  (<days> days)
**Key size:**      <bits>-bit RSA (no passphrase)
**Private key:**   <path>  (chmod 600 — DO NOT SHARE)
**Certificate:**   <path>
**Fingerprint:**   SHA256 <hex>
**Self-signed:**   issuer == subject ✅

### Quick test
  openssl x509 -in <cert-path> -noout -text
  # Use with nginx:
  ssl_certificate     <cert-path>;
  ssl_certificate_key <key-path>;

⚠️ Self-signed — browsers will show a warning until you install <cert-path> in your OS trust store.
⚠️ Private key saved to <key-path>. Never commit it to git.
```

NEVER print the contents of the `.key` file.

## Gotchas

- **Browser still warns even with valid SAN**: self-signed isn't in any trust store. Trust it explicitly:
  - macOS: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain <cert>`
  - Linux: copy to `/usr/local/share/ca-certificates/`, run `sudo update-ca-certificates`
- **CN deprecated for hostname matching**: modern browsers (Chrome 58+) ignore CN and require SAN. Always pass `--san`.
- **`Can't load /home/<user>/.rnd`** warning: harmless on old OpenSSL. Newer 3.x doesn't need .rnd.
- **2048 vs 4096 bits**: 2048 is fine for everything until ~2030. 4096 doubles generation time.
- **Existing files refused**: this skill refuses to overwrite. Use a new `--name` or `rm` first.
- **For local dev with auto-trust**: use [mkcert](https://github.com/FiloSottile/mkcert) instead — it sets up a local CA and OS-trusted certs in one command.

## Cross-Platform Notes

- **OpenSSL 1.1 vs 3.x**: both support `-addext`. On macOS, LibreSSL (the default `openssl`) may differ — `brew install openssl` and use `/opt/homebrew/opt/openssl/bin/openssl` to get GNU/upstream OpenSSL.
- **PEM vs DER**: this skill outputs PEM (base64). Convert to DER with `openssl x509 -outform DER -in cert.crt -out cert.der` if your TLS library needs it.
- **Combined .pem (key + cert)**: `cat key.pem cert.pem > combined.pem` — some servers (HAProxy) expect this.
