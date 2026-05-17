---
name: cf-tools-net-ssl-check
description: "Fetch TLS cert via openssl s_client. Show issuer, expiry, SANs, chain depth. Trigger: /cf-tools-net-ssl-check"
trigger: /cf-tools-net-ssl-check
version: 1.0.0
---

# /cf-tools-net-ssl-check

Connect to a host on port 443 (or custom port), pull the TLS cert chain, and report subject, issuer, validity window, Subject Alternative Names, and days until expiry. Useful pre-deploy and during cert rotation.

## Usage

```
/cf-tools-net-ssl-check <host>
/cf-tools-net-ssl-check <host>:<port>
/cf-tools-net-ssl-check <host> --chain        # print full chain (not just leaf)
```

Arguments:
1. `host[:port]` (required) — port defaults to 443
2. `--chain` (optional) — display intermediate certs too

## What You Must Do When Invoked

### Step 1 — Parse host:port

```bash
TARGET="$1"
shift
CHAIN=0
for a in "$@"; do
  case "$a" in --chain) CHAIN=1 ;; esac
done

if [[ "$TARGET" == *:* ]]; then
  HOST="${TARGET%:*}"
  PORT="${TARGET##*:}"
else
  HOST="$TARGET"
  PORT=443
fi

if [ -z "$HOST" ]; then
  echo "ERROR: host required" >&2
  exit 1
fi
```

### Step 2 — Pull the cert chain

```bash
# -showcerts: print the full chain
# -servername: SNI (required for shared TLS hosts)
# stdin closed via `</dev/null` so s_client exits after handshake
RAW=$(openssl s_client -showcerts -connect "${HOST}:${PORT}" -servername "$HOST" </dev/null 2>/dev/null)
if [ -z "$RAW" ]; then
  echo "ERROR: failed to connect to ${HOST}:${PORT}" >&2
  exit 1
fi
```

### Step 3 — Parse the leaf cert

```bash
LEAF=$(echo "$RAW" | awk '/-----BEGIN CERTIFICATE-----/{flag=1} flag; /-----END CERTIFICATE-----/{exit}')

echo "TLS certificate: ${HOST}:${PORT}"
echo ""
echo "--- Leaf ---"
echo "$LEAF" | openssl x509 -noout \
  -subject -issuer -dates -ext subjectAltName -fingerprint -sha256 2>/dev/null

# Days until expiry
EXP=$(echo "$LEAF" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
EXP_SEC=$(date -j -f "%b %e %T %Y %Z" "$EXP" +%s 2>/dev/null \
       || date -d "$EXP" +%s 2>/dev/null)
NOW_SEC=$(date +%s)
DAYS=$(( (EXP_SEC - NOW_SEC) / 86400 ))

echo ""
if   [ "$DAYS" -lt 0 ];   then echo "❌ EXPIRED ${DAYS#-} days ago"
elif [ "$DAYS" -lt 14 ];  then echo "⚠️  Expires in $DAYS days — renew soon"
elif [ "$DAYS" -lt 30 ];  then echo "ℹ️  Expires in $DAYS days"
else echo "✅ Valid for $DAYS more days"
fi
```

### Step 4 — Optional chain dump

```bash
if [ "$CHAIN" -eq 1 ]; then
  echo ""
  echo "--- Full chain ---"
  echo "$RAW" | awk '
    /-----BEGIN CERTIFICATE-----/{cert=""; flag=1}
    flag{cert=cert $0 "\n"}
    /-----END CERTIFICATE-----/{flag=0; print cert | "openssl x509 -noout -subject -issuer"; close("openssl x509 -noout -subject -issuer"); print ""}
  '
fi
```

## Output Contract

```
TLS certificate: anthropic.com:443

--- Leaf ---
subject=CN=anthropic.com
issuer=C=US, O=Let's Encrypt, CN=E8
notBefore=Apr  7 15:34:43 2026 GMT
notAfter=Jul  6 15:34:42 2026 GMT
X509v3 Subject Alternative Name:
    DNS:anthropic.com, DNS:www.anthropic.com
SHA256 Fingerprint=AB:CD:...

✅ Valid for 50 more days
```

## Gotchas

- **Missing SNI** → some hosts (CloudFront, GitHub Pages, shared edges) return a default cert that doesn't match the hostname. Always pass `-servername "$HOST"`.
- **Stale handshake hangs** — without `</dev/null`, `openssl s_client` waits for stdin. The `</dev/null` redirect is mandatory.
- **Certificate transparency / OCSP staple** parsing not covered here. Use `openssl s_client -status` for OCSP.
- **Wildcard SAN matching** — `*.example.com` matches `a.example.com` but NOT `example.com` itself nor `a.b.example.com`. Mention this when reporting SANs if user asks about subdomains.
- **BSD `date -j -f` format string for openssl output** — locale-sensitive. The format `"%b %e %T %Y %Z"` works for `MAY 17 12:00:00 2026 GMT`; if locale differs, fall back to python parsing.
- **Self-signed / expired certs** — `openssl s_client` still pulls the cert and the skill should still display info, just with a clear warning.

## Cross-Platform Notes

- **macOS**: `openssl` from Homebrew (`/usr/local/bin/openssl` or `/opt/homebrew/bin/openssl`) is preferred — the system `/usr/bin/openssl` is actually LibreSSL with different flags.
- **Linux**: stock `openssl` works.
- **GNU `date -d`** is used as fallback for the date math (BSD on macOS, GNU on Linux).
- **Alternative**: `nmap --script ssl-cert -p 443 <host>` gives similar info with chain validation, if installed.
