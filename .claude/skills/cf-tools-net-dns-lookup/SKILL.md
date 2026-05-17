---
name: cf-tools-net-dns-lookup
description: "Show A, AAAA, MX, TXT, NS, CNAME records for a domain in one table. Trigger: /cf-tools-net-dns-lookup"
trigger: /cf-tools-net-dns-lookup
version: 1.0.0
---

# /cf-tools-net-dns-lookup

Run `dig` for all common record types and present results as a single readable table. Useful when debugging mail (MX/TXT), CDN failover (CNAME/A), nameserver moves (NS), or SPF/DKIM/DMARC (TXT).

## Usage

```
/cf-tools-net-dns-lookup <domain>
/cf-tools-net-dns-lookup <domain> @1.1.1.1     # use specific resolver
/cf-tools-net-dns-lookup <domain> --types A,MX # subset
```

Arguments:
1. `domain` (required) — apex domain or subdomain
2. `@<resolver>` (optional) — override resolver (default: system)
3. `--types` (optional, default `A,AAAA,MX,TXT,NS,CNAME,SOA`) — comma list

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
DOMAIN="$1"
shift
RESOLVER=""
TYPES="A,AAAA,MX,TXT,NS,CNAME,SOA"
for a in "$@"; do
  case "$a" in
    @*) RESOLVER="$a" ;;
    --types) shift; TYPES="$1" ;;
    --types=*) TYPES="${a#*=}" ;;
  esac
done

if [ -z "$DOMAIN" ]; then
  echo "ERROR: domain required" >&2
  exit 1
fi
```

### Step 2 — Query each record type with `dig +short`

```bash
echo "DNS lookup: $DOMAIN ${RESOLVER:+via $RESOLVER}"
echo ""
printf "%-7s | %s\n" "TYPE" "ANSWER"
printf "%-7s-+-%s\n" "-------" "----------------------------------------"

IFS=',' read -ra TYPE_ARR <<< "$TYPES"
for t in "${TYPE_ARR[@]}"; do
  ANS=$(dig +short ${RESOLVER} "$DOMAIN" "$t" 2>/dev/null)
  if [ -z "$ANS" ]; then
    printf "%-7s | %s\n" "$t" "(none)"
  else
    # Print first line on the type row, subsequent indented
    FIRST=1
    while IFS= read -r line; do
      if [ "$FIRST" -eq 1 ]; then
        printf "%-7s | %s\n" "$t" "$line"
        FIRST=0
      else
        printf "%-7s | %s\n" "" "$line"
      fi
    done <<< "$ANS"
  fi
done
```

### Step 3 — Highlight common health signals

After the table, the skill should call out:
- **No MX records** → mail will bounce. Confirm if domain is parked or web-only.
- **MX present but no SPF (no `v=spf1` TXT)** → spoofing risk; mail may go to spam.
- **Multiple CNAMEs on the same name** → invalid per RFC; flag it.
- **NS records mismatch with registrar** (out of scope here, but mention `/cf-tools-net-whois-lookup` for verification).

```bash
HAS_MX=$(dig +short "$DOMAIN" MX | head -1)
HAS_SPF=$(dig +short "$DOMAIN" TXT | grep -c 'v=spf1')

[ -z "$HAS_MX" ]    && echo "⚠️  No MX records — domain cannot receive mail."
[ "$HAS_SPF" -eq 0 ] && [ -n "$HAS_MX" ] && echo "⚠️  MX present but no SPF TXT — mail may be flagged."
```

## Output Contract

```
DNS lookup: anthropic.com

TYPE    | ANSWER
--------+----------------------------------------
A       | 160.79.104.10
AAAA    | (none)
MX      | 1 aspmx.l.google.com.
        | 5 alt1.aspmx.l.google.com.
        | 5 alt2.aspmx.l.google.com.
        | 10 alt3.aspmx.l.google.com.
        | 10 alt4.aspmx.l.google.com.
TXT     | "v=spf1 include:_spf.google.com ~all"
NS      | ns-cloud-d1.googledomains.com.
        | ns-cloud-d2.googledomains.com.
CNAME   | (none)
SOA     | ns-cloud-d1.googledomains.com. cloud-dns-hostmaster.google.com. 1 21600 3600 259200 300
```

## Gotchas

- **`dig +short` strips TTL** — use `dig <domain> <type>` (no `+short`) if TTLs matter; this skill optimises for readability.
- **CNAME apex disallowed** — if a user queries CNAME for an apex domain (e.g. `example.com` not `www.example.com`), expect `(none)` even when "ALIAS" / "ANAME" exists at the registrar.
- **TXT records with embedded quotes**: dig returns them quoted; do NOT strip quotes — they're part of the record format.
- **`dig` not on PATH on Linux minimal containers** — `apt install dnsutils` or `apk add bind-tools` on Alpine.
- **Resolver caching skews results during DNS migrations** — pass `@1.1.1.1` or `@8.8.8.8` to bypass local cache.

## Cross-Platform Notes

- **macOS**: `dig` ships in `/usr/bin/dig`.
- **Linux**: install `dnsutils` (Debian/Ubuntu) or `bind-utils` (RHEL/Fedora).
- **Windows**: PowerShell `Resolve-DnsName <domain>` is the closest equivalent; this skill assumes WSL or Git Bash for `dig`.
- **`host` fallback**: if `dig` missing but `host` present, the skill could degrade gracefully — but `host` output is harder to format. Out of scope for v1.
