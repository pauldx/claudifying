---
name: cf-tools-shell-kill-port
description: "Find and kill the process listening on a port. Dry-run by default, --execute to actually send the signal. Trigger: /cf-tools-shell-kill-port"
trigger: /cf-tools-shell-kill-port
version: 1.0.0
---

# /cf-tools-shell-kill-port

Free a stuck port. Identifies the PID listening on a given port, then signals it. Defaults to a DRY-RUN preview — you must pass `--execute` to actually send a signal.

## Usage

```
/cf-tools-shell-kill-port 3000                              # dry-run: shows what would die
/cf-tools-shell-kill-port 3000 --execute                    # actually send TERM
/cf-tools-shell-kill-port 3000 --execute --signal KILL      # force kill (-9)
/cf-tools-shell-kill-port 8080 --execute --proto udp        # UDP port
```

Arguments:
1. `port` (required, positional) — port number
2. `--execute` (optional flag) — actually send the signal (default is dry-run)
3. `--signal NAME` (optional, default `TERM`) — TERM (graceful) or KILL (forceful)
4. `--proto tcp|udp` (optional, default `tcp`)

## What You Must Do When Invoked

### Step 1 — Validate args

```bash
PORT="<arg1>"
EXECUTE="${EXECUTE:-0}"
SIGNAL="${SIGNAL:-TERM}"
PROTO="${PROTO:-tcp}"

[ -z "$PORT" ] && { echo "ERROR: port number required"; exit 1; }
case "$SIGNAL" in TERM|KILL|HUP|INT|QUIT) ;; *) echo "ERROR: --signal must be TERM, KILL, HUP, INT, or QUIT"; exit 1 ;; esac
```

### Step 2 — Find the PID(s)

```bash
case "$PROTO" in
  tcp) PIDS=$(lsof -nP -ti "tcp:$PORT" -sTCP:LISTEN 2>/dev/null) ;;
  udp) PIDS=$(lsof -nP -ti "udp:$PORT" 2>/dev/null) ;;
esac

if [ -z "$PIDS" ]; then
  echo "✅ Nothing listening on $PROTO:$PORT — port is free."
  exit 0
fi
```

### Step 3 — Show details for each PID

```bash
echo "Processes on $PROTO:$PORT:"
for pid in $PIDS; do
  CMD=$(ps -p "$pid" -o command= 2>/dev/null | head -c 200)
  USER=$(ps -p "$pid" -o user= 2>/dev/null)
  ELAPSED=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ')
  echo "  PID $pid  user=$USER  uptime=$ELAPSED"
  echo "    cmd: $CMD"
done
```

### Step 4 — Dry-run preview or actual kill

```bash
if [ "$EXECUTE" != "1" ]; then
  echo ""
  echo "🔍 DRY-RUN — no signals sent."
  echo "    To actually kill: rerun with --execute --signal $SIGNAL"
  exit 0
fi

echo ""
echo "⚡ Sending SIG$SIGNAL to: $PIDS"
for pid in $PIDS; do
  if kill -s "$SIGNAL" "$pid" 2>&1; then
    echo "  ✅ PID $pid signaled"
  else
    echo "  ❌ PID $pid — kill failed (try sudo?)"
  fi
done
```

### Step 5 — Verify (TERM only — KILL is instant)

```bash
if [ "$SIGNAL" = "TERM" ]; then
  sleep 1
  STILL=$(lsof -nP -ti "${PROTO}:$PORT" $([ "$PROTO" = "tcp" ] && echo "-sTCP:LISTEN") 2>/dev/null)
  if [ -z "$STILL" ]; then
    echo "🎉 Port $PORT is now free."
  else
    echo "⚠️  PIDs still listening after TERM: $STILL"
    echo "    Process may need SIGKILL: rerun with --execute --signal KILL"
  fi
fi
```

## Output Contract

Dry-run:
```
## Kill port preview — DRY RUN

**Port:**      3000/tcp
**Found:**     2 processes

Processes on tcp:3000:
  PID 78332  user=debashispaul  uptime=02:15:43
    cmd: node /path/to/server.js
  PID 78333  user=debashispaul  uptime=02:15:43
    cmd: node /path/to/worker.js

🔍 DRY-RUN — no signals sent.
   To actually kill: rerun with --execute --signal TERM
```

Execute:
```
## Kill port

**Port:**     3000/tcp
**Signal:**   TERM
**PIDs:**     78332 78333
**Result:**   ✅ both signaled, port freed | ⚠️ still listening
```

## Gotchas

- **Always dry-run first**: the default. Required to prevent accidentally killing your IDE / database / Docker.
- **TERM vs KILL**: TERM lets the process clean up (close sockets, flush DBs). KILL is instant + uncatchable. Try TERM first.
- **Same PID listening on multiple ports**: killing it frees them all. The skill only shows what's on the requested port — read the cmd before executing.
- **`sudo` needed for other-user processes**: macOS lsof refuses to identify other users' sockets without root. Tell user to rerun with `sudo`.
- **Zombies**: a process killed with KILL leaves a zombie until its parent reaps. The port frees instantly regardless.
- **Docker port mapping**: killing `docker-proxy` on the host kills the mapping; the container keeps running. To kill the container's process, `docker stop <id>` instead.
- **systemd-managed services**: kill returns success but systemd restarts the service in 1s. Use `systemctl stop <unit>` instead.

## Cross-Platform Notes

- **macOS / Linux**: lsof flags identical.
- **No lsof installed**: fall back to `fuser -k -n tcp $PORT` (Linux) or `Get-Process -Id (Get-NetTCPConnection -LocalPort $PORT).OwningProcess` (Windows PowerShell).
- **Containers**: this skill operates on the host's port mappings. To kill inside a container: `docker exec <id> kill <pid>`.
