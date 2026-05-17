---
name: cf-tools-net-whois-lookup
description: "Run whois on a domain and extract registrar, dates, status, nameservers. Trigger: /cf-tools-net-whois-lookup"
trigger: /cf-tools-net-whois-lookup
version: 1.0.0
---

# /cf-tools-net-whois-lookup

Query the WHOIS system for a domain. Extracts the load-bearing fields (registrar, creation/expiry/updated, status, nameservers) instead of dumping the full noisy record. Useful for domain due diligence, expiry monitoring, and registrar audits.

## Usage

```
/cf-tools-net-whois-lookup <domain>
/cf-tools-net-whois-lookup <domain> --raw       # full output, no parsing
/cf-tools-net-whois-lookup <domain> --server whois.nic.uk
```

Arguments:
1. `domain` (required)
2. `--raw` (optional) — print raw output
3. `--server <host>` (optional) — query a specific WHOIS server (rare; usually IANA referral works)

## What You Must Do When Invoked

### Step 1 — Validate args

```bash
DOMAIN="$1"
shift
RAW=0
SERVER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --raw) RAW=1 ;;
    --server) shift; SERVER="$1" ;;
  esac
  shift
done

if [ -z "$DOMAIN" ]; then
  echo "ERROR: domain required" >&2
  exit 1
fi
if ! command -v whois >/dev/null 2>&1; then
  echo "ERROR: whois not installed. macOS: brew install whois  |  Debian: apt install whois" >&2
  exit 1
fi
```

### Step 2 — Run whois

```bash
if [ -n "$SERVER" ]; then
  RESP=$(whois -h "$SERVER" "$DOMAIN" 2>/dev/null)
else
  RESP=$(whois "$DOMAIN" 2>/dev/null)
fi

if [ "$RAW" -eq 1 ]; then
  echo "$RESP"
  exit 0
fi
```

### Step 3 — Extract key fields

WHOIS output is gloriously non-standard; field names differ per registry. Match the common variants case-insensitively:

```bash
extract() {
  local pattern="$1"
  echo "$RESP" | grep -iE "^[[:space:]]*${pattern}:" \
    | head -5 | sed 's/^[[:space:]]*//; s/^[A-Za-z ]*:[[:space:]]*//'
}

REGISTRAR=$(extract "registrar")
CREATED=$(extract "(creation date|created|registered on|registered)")
UPDATED=$(extract "(updated date|last updated|changed)")
EXPIRES=$(extract "(registry expiry date|registrar registration expiration date|expir(y|ation) date|paid-till)")
STATUS=$(extract "(domain status|status)")
NSERVERS=$(echo "$RESP" | grep -iE "^[[:space:]]*name server:" | sed 's/^[^:]*:[[:space:]]*//' | sort -u)
DNSSEC=$(extract "dnssec")

echo "WHOIS: $DOMAIN"
echo ""
echo "Registrar:     ${REGISTRAR:-(not parsed)}"
echo "Created:       ${CREATED:-(not parsed)}"
echo "Updated:       ${UPDATED:-(not parsed)}"
echo "Expires:       ${EXPIRES:-(not parsed)}"
echo "DNSSEC:        ${DNSSEC:-(not parsed)}"
echo ""
echo "Status:"
echo "$STATUS" | sed 's/^/  - /'
echo ""
echo "Nameservers:"
echo "$NSERVERS" | sed 's/^/  - /'
```

### Step 4 — Surface expiry warning

```bash
if [ -n "$EXPIRES" ]; then
  # Try ISO-ish parse — WHOIS dates vary wildly, this is best-effort
  EXP_SEC=$(python3 -c "
import sys, datetime, re
s = sys.argv[1].strip()
for fmt in ('%Y-%m-%dT%H:%M:%SZ','%Y-%m-%dT%H:%M:%S.%fZ','%Y-%m-%d','%d-%b-%Y','%d.%m.%Y'):
    try: print(int(datetime.datetime.strptime(s.split()[0], fmt).timestamp())); sys.exit(0)
    except: pass
" "$EXPIRES" 2>/dev/null)
  if [ -n "$EXP_SEC" ]; then
    NOW=$(date +%s)
    DAYS=$(( (EXP_SEC - NOW) / 86400 ))
    if   [ "$DAYS" -lt 0 ];  then echo "❌ Domain expired ${DAYS#-} days ago"
    elif [ "$DAYS" -lt 30 ]; then echo "⚠️  Domain expires in $DAYS days"
    else echo "✅ Domain expires in $DAYS days"
    fi
  fi
fi
```

## Output Contract

```
WHOIS: anthropic.com

Registrar:     MarkMonitor Inc.
Created:       2014-04-08T20:23:43Z
Updated:       2025-03-14T12:00:01Z
Expires:       2027-04-08T20:23:43Z
DNSSEC:        unsigned

Status:
  - clientTransferProhibited https://icann.org/epp#clientTransferProhibited

Nameservers:
  - ns-cloud-d1.googledomains.com
  - ns-cloud-d2.googledomains.com

✅ Domain expires in 692 days
```

## Gotchas

- **WHOIS is not standardised** — field names and date formats vary across TLDs and registries. The skill parses common forms but always falls back to `(not parsed)` rather than guessing.
- **Privacy-protected domains** hide registrant — Registrar, dates, and NS are still returned, but Registrant/Admin/Tech contacts will be redacted. Don't promise contact info.
- **`.io`, `.ai`, `.uk`, `.de`** use ccTLD-specific servers — `whois` follows the IANA referral most of the time, but pass `--server` if you get an empty record.
- **Rate-limited per IP**: Verisign throttles `.com`/`.net` queries to ~30/min. Bulk users need RDAP or a commercial API.
- **macOS Apple Silicon `whois` is system-provided** but on some installs not — confirm and document `brew install whois` if missing.
- **GDPR redaction** removed most personal data post-2018; this is permanent for most EU TLDs.
- **RDAP (the modern replacement)**: `curl https://rdap.org/domain/<domain> | jq` returns JSON. Mention this if user wants programmatic access.

## Cross-Platform Notes

- **macOS**: ships with `/usr/bin/whois`. If missing (Apple Silicon minimal installs): `brew install whois`.
- **Linux**: `apt install whois` or `dnf install whois`.
- **Windows**: PowerShell has no native whois; recommend Sysinternals `whois.exe` or WSL.
