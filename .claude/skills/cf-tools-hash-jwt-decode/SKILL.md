---
name: cf-tools-hash-jwt-decode
description: "Decode a JWT (header + payload, base64url). Optional HMAC signature verification with --secret. Trigger: /cf-tools-hash-jwt-decode"
trigger: /cf-tools-hash-jwt-decode
version: 1.0.0
---

# /cf-tools-hash-jwt-decode

Split a JWT, base64url-decode the header and payload, pretty-print the JSON. By default the signature is shown but NOT verified — verification only runs when `--secret` is provided and the algorithm is HMAC (HS256/HS384/HS512). For RS/ES/Ed signatures, decode-only.

## Usage

```
/cf-tools-hash-jwt-decode <jwt>
/cf-tools-hash-jwt-decode <jwt> --secret <hmac-secret>
/cf-tools-hash-jwt-decode -                # read JWT from stdin
```

Arguments:
1. JWT string (or `-` to read from stdin)
2. `--secret <s>` (optional) — HMAC secret for HS256/384/512 verification

## What You Must Do When Invoked

### Step 1 — Read the token

```bash
JWT="$1"
shift
SECRET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --secret) shift; SECRET="$1" ;;
  esac
  shift
done

if [ "$JWT" = "-" ]; then
  JWT="$(cat)"
fi
JWT=$(echo "$JWT" | tr -d '[:space:]')

if [ -z "$JWT" ] || [ "$(echo "$JWT" | tr -cd '.' | wc -c)" -ne 2 ]; then
  echo "ERROR: JWT must have exactly 3 dot-separated parts" >&2; exit 1
fi

H_B64="${JWT%%.*}"
REST="${JWT#*.}"
P_B64="${REST%%.*}"
S_B64="${REST#*.}"
```

### Step 2 — Base64url decode header + payload

JWT uses base64**url** (RFC 4648 §5): `-` and `_` instead of `+` and `/`, padding optional.

```bash
b64url_decode() {
  local s="$1"
  # restore +/, pad to multiple of 4
  s=$(echo "$s" | tr '_-' '/+')
  case $((${#s} % 4)) in
    2) s="${s}==" ;;
    3) s="${s}=" ;;
  esac
  echo "$s" | base64 -d 2>/dev/null
}

HEADER_JSON=$(b64url_decode "$H_B64")
PAYLOAD_JSON=$(b64url_decode "$P_B64")

if [ -z "$HEADER_JSON" ] || [ -z "$PAYLOAD_JSON" ]; then
  echo "ERROR: failed to base64url-decode header or payload" >&2; exit 1
fi
```

### Step 3 — Pretty-print + extract claims

```bash
echo "--- Header ---"
if command -v jq >/dev/null; then echo "$HEADER_JSON" | jq .; else echo "$HEADER_JSON"; fi

echo "--- Payload ---"
if command -v jq >/dev/null; then echo "$PAYLOAD_JSON" | jq .; else echo "$PAYLOAD_JSON"; fi

# Decode standard time claims if present
if command -v jq >/dev/null; then
  for claim in iat nbf exp; do
    V=$(echo "$PAYLOAD_JSON" | jq -r ".${claim} // empty")
    if [ -n "$V" ]; then
      ISO=$(date -r "$V" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
         || date -u -d "@$V" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
      echo "  $claim = $V → $ISO"
    fi
  done

  EXP=$(echo "$PAYLOAD_JSON" | jq -r '.exp // empty')
  if [ -n "$EXP" ]; then
    NOW=$(date +%s)
    if [ "$NOW" -ge "$EXP" ]; then echo "❌ Token EXPIRED"; else echo "✅ Token valid for $((EXP-NOW))s more"; fi
  fi
fi

echo "--- Signature (base64url) ---"
echo "$S_B64"
```

### Step 4 — Verify only if --secret AND HMAC algorithm

```bash
if [ -n "$SECRET" ] && command -v jq >/dev/null; then
  ALG=$(echo "$HEADER_JSON" | jq -r '.alg // empty')
  case "$ALG" in
    HS256|HS384|HS512)
      DIGEST=${ALG#HS}
      SIGNING_INPUT="${H_B64}.${P_B64}"
      # openssl HMAC, base64url-encoded
      EXPECTED=$(printf '%s' "$SIGNING_INPUT" \
        | openssl dgst -sha${DIGEST} -hmac "$SECRET" -binary \
        | base64 \
        | tr '+/' '-_' | tr -d '=')
      if [ "$EXPECTED" = "$S_B64" ]; then
        echo "✅ HMAC signature VALID"
      else
        echo "❌ HMAC signature INVALID"
        echo "   expected: $EXPECTED"
        echo "   got:      $S_B64"
      fi
      ;;
    RS256|RS384|RS512|ES256|ES384|ES512|EdDSA|PS256|PS384|PS512)
      echo "ℹ️  alg=$ALG uses public-key crypto — verification needs the issuer's public key, not a shared secret. Decode-only."
      ;;
    none)
      echo "⚠️  alg=none — token is unsigned. Reject in any real auth flow."
      ;;
    *)
      echo "ℹ️  Unknown alg=$ALG — not verifying."
      ;;
  esac
fi
```

## Output Contract

```
--- Header ---
{
  "alg": "HS256",
  "typ": "JWT"
}
--- Payload ---
{
  "sub": "1234567890",
  "name": "John Doe",
  "iat": 1516239022
}
  iat = 1516239022 → 2018-01-18T01:30:22Z
--- Signature (base64url) ---
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

With `--secret`:
```
✅ HMAC signature VALID
```

## Gotchas

- **NEVER trust an unverified JWT for auth decisions.** This skill defaults to decode-only on purpose. Don't add a `--trust` shortcut.
- **`alg: none` attack** — historical JWT libraries treated `alg: "none"` as valid with empty signature. The skill flags it but does not "verify" it. Reject in production.
- **HS256 with RSA public key as the secret** — classic confused-deputy bug. If the user passes an RSA public key as `--secret`, the HMAC will succeed against an attacker-forged token. The skill cannot detect this; document it.
- **Base64url padding**: the implementation above pads to multiples of 4. macOS `base64 -d` is strict about padding; without it, you'll get `invalid input`.
- **`date -r <epoch>` is BSD**, `date -d @<epoch>` is GNU. The skill tries both.
- **Claims `iat`/`nbf`/`exp`** are seconds, not milliseconds. If you see a 13-digit number, it's ms — divide by 1000 before formatting (skill assumes seconds; flag if number > 99999999999).
- **JWS vs JWE**: this skill handles JWS (3 segments). JWE has 5 segments — the skill refuses cleanly via the part-count check.

## Cross-Platform Notes

- **macOS / Linux**: `base64`, `openssl`, `jq` all available. Skill works identically.
- **`base64 -d` vs `base64 --decode`**: macOS supports `-d`; GNU coreutils supports both. Use `-d`.
- **Alternative**: `python3 -c "import base64,json;..."` works everywhere if any of the above is missing. Not used here to keep zero-Python in the happy path.
- **Note on Ed25519 / EdDSA**: stdlib openssl supports `pkeyutl` for verification but it's nontrivial; out of scope for v1.
