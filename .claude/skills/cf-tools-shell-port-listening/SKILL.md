---
name: cf-tools-shell-port-listening
description: "List ports being listened on with PID, process name, and user via lsof. Trigger: /cf-tools-shell-port-listening"
trigger: /cf-tools-shell-port-listening
version: 1.0.0
---

# /cf-tools-shell-port-listening

Show every TCP/UDP port currently in LISTEN state on this machine, along with the PID, process name, and user that owns it. Answers "what's eating port 3000?" without grep gymnastics.

## Usage

```
/cf-tools-shell-port-listening
/cf-tools-shell-port-listening --port 3000           # only port 3000
/cf-tools-shell-port-listening --proto tcp           # tcp only (default both)
/cf-tools-shell-port-listening --user me             # only my processes
```

Arguments:
1. `--port N` (optional) — filter to one port number
2. `--proto tcp|udp|both` (optional, default `both`)
3. `--user STRING` (optional) — filter by owning username

## What You Must Do When Invoked

### Step 1 — Pick the listing tool

```bash
if command -v lsof >/dev/null; then
  TOOL="lsof"
elif command -v ss >/dev/null; then
  TOOL="ss"
elif command -v netstat >/dev/null; then
  TOOL="netstat"
else
  echo "ERROR: need lsof, ss, or netstat"
  exit 1
fi
```

Preference order: lsof > ss > netstat (lsof works everywhere; ss is best on Linux; netstat is legacy).

### Step 2 — Build the listing

```bash
PROTO="${PROTO:-both}"
USER_FILTER="${USER_FILTER:-}"
PORT_FILTER="${PORT_FILTER:-}"

case "$TOOL" in
  lsof)
    FLAGS="-nP -iTCP -sTCP:LISTEN"
    [ "$PROTO" = "udp" ] && FLAGS="-nP -iUDP"
    [ "$PROTO" = "both" ] && {
      lsof -nP -iTCP -sTCP:LISTEN
      lsof -nP -iUDP
    } > /tmp/.ports-raw 2>/dev/null
    [ "$PROTO" != "both" ] && lsof $FLAGS > /tmp/.ports-raw 2>/dev/null
    ;;
  ss)
    case "$PROTO" in
      tcp)  ss -tlnp > /tmp/.ports-raw ;;
      udp)  ss -ulnp > /tmp/.ports-raw ;;
      both) ss -tulnp > /tmp/.ports-raw ;;
    esac
    ;;
  netstat)
    netstat -tulnp 2>/dev/null > /tmp/.ports-raw
    ;;
esac
```

### Step 3 — Parse + filter into a uniform table

```bash
# Goal columns: PROTO  PORT  PID  USER  COMMAND  ADDRESS
# lsof example line:
#   nginx  1234  www-data  6u  IPv4  TCP *:80 (LISTEN)
# Parse PORT from NAME column (last field before "(LISTEN)").

# Apply filters
[ -n "$PORT_FILTER" ] && grep -E ":(${PORT_FILTER})( |$|\b)" /tmp/.ports-raw
[ -n "$USER_FILTER" ] && grep -E "\\s${USER_FILTER}\\s" /tmp/.ports-raw
```

Render as a sorted, aligned table sorted by port ascending.

### Step 4 — Render

Print a header row + parsed rows. If the user filtered to one port and nothing matches, print "Port <N> is FREE".

## Output Contract

```
## Listening ports

| PROTO | PORT  | PID    | USER         | COMMAND       | ADDRESS         |
|-------|-------|--------|--------------|---------------|-----------------|
| TCP   |    22 |    501 | root         | sshd          | *               |
| TCP   |  3000 |  78332 | debashispaul | node          | 127.0.0.1       |
| TCP   |  5432 |   1212 | postgres     | postgres      | *               |
| UDP   |  5353 |    412 | _mdnsrespond | mDNSResponder | *               |

**Total:** <N> listening sockets
**Filter:** port=3000 | proto=tcp | user=me  (or "none")
```

If filtered to a specific port with no match:

```
## Port 3000 is FREE — no process listening on TCP/UDP 3000.
```

## Gotchas

- **lsof on macOS often needs sudo for other users' processes**: skill output may be incomplete without sudo. Note this if user count seems low.
- **Same port on TCP and UDP**: legitimate (e.g., DNS). Both rows will appear when `--proto both`.
- **Docker host networking**: containers using `--network=host` show as the container process. Bridge-network containers show as `docker-proxy` listening on the host port.
- **IPv4 vs IPv6 dual-listen**: many daemons bind to both. lsof shows two rows (`*` IPv4 and `*` IPv6); the skill shows both.
- **Port number vs service name**: lsof tries to resolve well-known ports to names (80 → http). `-P` (used here) keeps numeric output — easier to filter.
- **`-n`** keeps addresses numeric (don't DNS-resolve `127.0.0.1` to `localhost`). Faster + clearer.

## Cross-Platform Notes

- **macOS**: lsof preinstalled. ss/netstat absent.
- **Linux**: ss + lsof both available. ss is faster on busy hosts.
- **Windows**: `Get-NetTCPConnection -State Listen` in PowerShell. Or `netstat -ano | findstr LISTENING`.
- **Containers**: this skill shows the *host's* listeners. To see what's listening *inside* a container: `docker exec <id> ss -tlnp`.
