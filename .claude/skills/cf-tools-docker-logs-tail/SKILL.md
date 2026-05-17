---
name: cf-tools-docker-logs-tail
description: "Tail logs for one or all running containers with --since/--lines/--follow. Trigger: /cf-tools-docker-logs-tail"
trigger: /cf-tools-docker-logs-tail
version: 1.0.0
---

# /cf-tools-docker-logs-tail

Tail container logs with timestamps and per-container prefixing. Defaults to last 10 minutes across ALL running containers. Multi-container mode interleaves output with `[container-name]` prefix for grep-ability.

## Usage

```
/cf-tools-docker-logs-tail                          # all running, last 10m, no follow
/cf-tools-docker-logs-tail web                      # single container
/cf-tools-docker-logs-tail --follow                 # live tail all
/cf-tools-docker-logs-tail web --follow --since=1h
/cf-tools-docker-logs-tail --lines=200              # last 200 lines per container
/cf-tools-docker-logs-tail --grep=ERROR --since=30m # filter
```

Arguments:
- `<container>` (optional positional) — single container; omit for all running
- `--since=<duration>` (default `10m`) — `30m`, `2h`, `1h30m`, or RFC3339 timestamp
- `--lines=<N>` — instead of `--since`, last N lines per container
- `--follow` — stream new logs (Ctrl-C to exit)
- `--grep=<pattern>` — filter to matching lines (case-insensitive)
- `--no-prefix` — omit `[name]` prefix even in multi-container mode

## What You Must Do When Invoked

### Step 1 — Preflight

```bash
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker CLI not installed."; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: Docker daemon not running."; exit 1; }
```

### Step 2 — Resolve target containers

```bash
if [ -n "$CONTAINER" ]; then
  TARGETS=("$CONTAINER")
else
  TARGETS=($(docker ps --format '{{.Names}}'))
  if [ ${#TARGETS[@]} -eq 0 ]; then
    echo "No running containers."
    exit 0
  fi
  echo "Tailing ${#TARGETS[@]} containers: ${TARGETS[*]}"
fi
```

### Step 3 — Build base flags

```bash
SINCE="${SINCE:-10m}"
LOGS_FLAGS=( --timestamps )

if [ -n "$LINES" ]; then
  LOGS_FLAGS+=( --tail "$LINES" )
else
  LOGS_FLAGS+=( --since "$SINCE" )
fi

[ "$FOLLOW" = "1" ] && LOGS_FLAGS+=( --follow )
```

### Step 4a — Single container path

```bash
if [ ${#TARGETS[@]} -eq 1 ]; then
  if [ -n "$GREP" ]; then
    docker logs "${LOGS_FLAGS[@]}" "${TARGETS[0]}" 2>&1 | grep -i --color=never "$GREP"
  else
    docker logs "${LOGS_FLAGS[@]}" "${TARGETS[0]}" 2>&1
  fi
  exit $?
fi
```

### Step 4b — Multi-container interleaved

```bash
# Spawn one `docker logs --follow` per container, prefix each line, fan-in to stdout
PIDS=()
trap 'kill ${PIDS[@]} 2>/dev/null' INT TERM EXIT

for c in "${TARGETS[@]}"; do
  (
    if [ "$NO_PREFIX" = "1" ]; then
      docker logs "${LOGS_FLAGS[@]}" "$c" 2>&1
    else
      docker logs "${LOGS_FLAGS[@]}" "$c" 2>&1 | sed "s/^/[$c] /"
    fi
  ) &
  PIDS+=($!)
done

if [ -n "$GREP" ]; then
  wait | grep -i --color=never "$GREP"
else
  wait
fi
```

## Output Contract

Non-follow mode prints to stdout, then summary:

```
## docker logs tail

**Containers:** <list>
**Window:**     --since=<duration> | --tail=<N>
**Follow:**     yes | no
**Grep:**       <pattern> | none
**Total lines:** <N>
```

Follow mode streams until interrupted; summary not printed (loop never exits cleanly).

## Gotchas

- **Driver matters**: `docker logs` only works for `json-file` and `journald` log drivers. For `syslog`, `gelf`, `awslogs`, etc., the command returns empty and prints "Error response from daemon: configured logging driver does not support reading".
- **`--since` parsing**: Docker accepts Go duration (`10m`, `2h45m`) OR RFC3339 (`2024-01-15T10:00:00Z`). Unix timestamps work too. Plain dates do NOT.
- **Multi-container interleaving** loses strict ordering — lines arrive in the order their stream's buffer flushes, not strict wall-clock. Add `--timestamps` (included) so user can re-sort if needed.
- **`docker logs --follow` does NOT exit when container stops** — it hangs. User must Ctrl-C.
- **Large `--tail`** (e.g. 100000) reads the entire log file; can spike memory in Docker Desktop's VM.
- **Daemon not running** during skill auth (darwin/arm64). Preflight catches this.

## Cross-Platform Notes

- **macOS / Windows**: logs come from Docker Desktop's VM; cross-platform identical behavior.
- **Linux journald driver**: prefer `journalctl CONTAINER_NAME=foo` for richer filtering; `docker logs` still works.
- **macOS Ctrl-C**: foregrounded `wait` may need two presses to fully kill all `docker logs` children.
