---
name: cf-tools-net-ip-info
description: "Look up geo / ASN / ISP for an IP or domain via ipinfo.io. Trigger: /cf-tools-net-ip-info"
trigger: /cf-tools-net-ip-info
version: 1.0.0
---

# /cf-tools-net-ip-info

Query `ipinfo.io` (free, no auth needed for low-volume) for geolocation, ASN, hostname, and organisation of an IPv4/IPv6 or a domain (resolves to A first). Handy when triaging an unknown IP in a server log.

## Usage

```
/cf-tools-net-ip-info <ip-or-domain>
/cf-tools-net-ip-info <ip-or-domain> --provider ip-api
```

Arguments:
1. `target` (required) — IPv4, IPv6, or domain
2. `--provider` (optional, default `ipinfo`) — `ipinfo` or `ip-api`

Both providers offer ~1k requests/day without an API key.

## What You Must Do When Invoked

### Step 1 — Resolve target to an IP if domain

```bash
TARGET="$1"
shift
PROVIDER="ipinfo"
for a in "$@"; do
  case "$a" in
    --provider) shift; PROVIDER="$1" ;;
    --provider=*) PROVIDER="${a#*=}" ;;
  esac
done

# Detect IP vs domain (very rough — IPs contain only digits/dots/colons)
if echo "$TARGET" | grep -qE '^[0-9a-fA-F.:]+$'; then
  IP="$TARGET"
else
  IP=$(dig +short "$TARGET" A | head -1)
  if [ -z "$IP" ]; then
    echo "ERROR: could not resolve $TARGET" >&2
    exit 1
  fi
  echo "Resolved $TARGET → $IP"
fi
```

### Step 2 — Query provider

```bash
case "$PROVIDER" in
  ipinfo) URL="https://ipinfo.io/$IP" ;;
  ip-api) URL="http://ip-api.com/json/$IP" ;;
  *) echo "ERROR: unknown provider $PROVIDER" >&2; exit 1 ;;
esac

RESP=$(curl -s "$URL")
if [ -z "$RESP" ]; then
  echo "ERROR: empty response from $PROVIDER" >&2
  exit 1
fi
```

### Step 3 — Normalize + display

```bash
if command -v jq >/dev/null 2>&1; then
  case "$PROVIDER" in
    ipinfo)
      echo "IP:       $(jq -r .ip       <<<"$RESP")"
      echo "Hostname: $(jq -r .hostname <<<"$RESP")"
      echo "Org:      $(jq -r .org      <<<"$RESP")"
      echo "City:     $(jq -r .city     <<<"$RESP")"
      echo "Region:   $(jq -r .region   <<<"$RESP")"
      echo "Country:  $(jq -r .country  <<<"$RESP")"
      echo "Location: $(jq -r .loc      <<<"$RESP")"
      echo "Timezone: $(jq -r .timezone <<<"$RESP")"
      echo "Anycast:  $(jq -r '.anycast // false' <<<"$RESP")"
      ;;
    ip-api)
      echo "IP:       $(jq -r .query   <<<"$RESP")"
      echo "ISP:      $(jq -r .isp     <<<"$RESP")"
      echo "Org:      $(jq -r .org     <<<"$RESP")"
      echo "AS:       $(jq -r .as      <<<"$RESP")"
      echo "City:     $(jq -r .city    <<<"$RESP")"
      echo "Region:   $(jq -r .regionName <<<"$RESP")"
      echo "Country:  $(jq -r .country <<<"$RESP")"
      echo "Lat/Lon:  $(jq -r '"\(.lat),\(.lon)"' <<<"$RESP")"
      echo "Timezone: $(jq -r .timezone <<<"$RESP")"
      ;;
  esac
else
  echo "$RESP"
fi
```

## Output Contract

```
Resolved anthropic.com → 160.79.104.10
IP:       160.79.104.10
Hostname: dns.google     (example)
Org:      AS15169 Google LLC
City:     Mountain View
Region:   California
Country:  US
Location: 37.4056,-122.0775
Timezone: America/Los_Angeles
Anycast:  true
```

## Gotchas

- **Free tier rate limits**: ipinfo.io throttles after ~50k/month per IP; ip-api.com hard-limits 45/minute. For bulk lookups, ask the user to add an API token.
- **`org` and `hostname` may be missing** on residential or unallocated IPs — jq prints `null`; the skill should display `(unknown)` for cleaner output.
- **Reverse-DNS lag** — newly assigned IPs lack PTR records for hours/days.
- **Private IPs (10/8, 172.16/12, 192.168/16)** return the lookup of the *requesting* IP, which is misleading. Reject these client-side:
  ```bash
  if echo "$IP" | grep -qE '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)'; then
    echo "ERROR: private IP, no public geo data" >&2; exit 1
  fi
  ```
- **HTTPS for ip-api requires paid plan** — that's why the URL above uses `http://`. Document this.
- **GDPR**: ipinfo.io drops some EU IP precision. Don't promise city-level accuracy.

## Cross-Platform Notes

- **All OS**: works as long as `curl` and (optionally) `jq` exist.
- **No-network environments**: skill should fail loud, not retry silently.
- **Alternative tools**: `whois -h whois.cymru.com " -v <ip>"` returns ASN data without an HTTP API, useful when only TCP/43 egress is allowed.
