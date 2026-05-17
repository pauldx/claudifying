---
name: cf-tools-docker-stats
description: "Snapshot running containers (CPU/mem/net/io) parsed into a clean table. Trigger: /cf-tools-docker-stats"
trigger: /cf-tools-docker-stats
version: 1.0.0
---

# /cf-tools-docker-stats

`docker stats` defaults to a live ANSI-redrawing stream that's unreadable in logs. This skill takes a single snapshot, parses it, and prints a clean fixed-width table sorted by CPU or memory.

## Usage

```
/cf-tools-docker-stats               # snapshot, sort by CPU descending
/cf-tools-docker-stats --sort=mem    # sort by memory %
/cf-tools-docker-stats --sort=name   # alphabetical
/cf-tools-docker-stats --container=<name>   # filter to one container
/cf-tools-docker-stats --json        # machine-readable JSON output
```

Arguments:
- `--sort=cpu|mem|name|netio|blkio` (default: `cpu`)
- `--container=<name-or-id>` — limit to one container
- `--json` — emit JSON array instead of table

## What You Must Do When Invoked

### Step 1 — Preflight

```bash
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker CLI not installed."; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: Docker daemon not running."; exit 1; }

RUNNING=$(docker ps -q | wc -l | tr -d ' ')
if [ "$RUNNING" = "0" ]; then
  echo "No running containers."
  exit 0
fi
```

### Step 2 — Take snapshot

```bash
# --no-stream takes ONE snapshot then exits (avoids ANSI stream)
docker stats --no-stream --format \
  '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}|{{.BlockIO}}|{{.PIDs}}' \
  > /tmp/docker-stats-$$.txt
```

### Step 3 — Sort + render

```bash
case "$SORT" in
  cpu)   SORT_KEY=2; NUMERIC=1 ;;
  mem)   SORT_KEY=4; NUMERIC=1 ;;
  name)  SORT_KEY=1; NUMERIC=0 ;;
  netio) SORT_KEY=5; NUMERIC=0 ;;
  blkio) SORT_KEY=6; NUMERIC=0 ;;
  *)     SORT_KEY=2; NUMERIC=1 ;;
esac

if [ "$NUMERIC" = "1" ]; then
  SORTED=$(sort -t'|' -k${SORT_KEY} -rn /tmp/docker-stats-$$.txt)
else
  SORTED=$(sort -t'|' -k${SORT_KEY} /tmp/docker-stats-$$.txt)
fi

printf '%-30s %8s %25s %8s %25s %25s %5s\n' \
  NAME CPU% MEM-USAGE MEM% NET-I/O BLOCK-I/O PIDS

echo "$SORTED" | awk -F'|' '{
  printf "%-30s %8s %25s %8s %25s %25s %5s\n", $1, $2, $3, $4, $5, $6, $7
}'

rm -f /tmp/docker-stats-$$.txt
```

### Step 4 — JSON mode

```bash
if [ "$JSON" = "1" ]; then
  docker stats --no-stream --format '{"name":"{{.Name}}","cpu":"{{.CPUPerc}}","mem":"{{.MemUsage}}","mem_pct":"{{.MemPerc}}","net":"{{.NetIO}}","blkio":"{{.BlockIO}}","pids":"{{.PIDs}}"}' \
    | jq -s '.'
fi
```

## Output Contract

```
## docker stats snapshot — sorted by <key>

NAME                          CPU%             MEM-USAGE     MEM%                  NET-I/O                BLOCK-I/O  PIDS
web-1                         12.34%   245MiB / 2GiB        12.25%   1.2MB / 800kB         12MB / 0B    8
db-1                           0.45%   512MiB / 2GiB        25.00%   200kB / 150kB        450MB / 12MB 12
...

**Total containers:** <N>
**Snapshot at:**      <timestamp>
```

## Gotchas

- **First-call cost**: cgroup v2 stats take ~1s to read. `docker stats --no-stream` is honest about this; don't loop tightly.
- **`--no-stream` is critical** — without it, the command never exits and pollutes Claude's context with ANSI redraws.
- **Memory reporting**: includes page cache by default. Container may show "high" memory but most is cache the kernel can evict. Don't alert on this alone.
- **NET-I/O cumulative**: counters reset only on container restart. For *rate*, take two snapshots N seconds apart and diff.
- **Docker daemon not running** during skill auth verification (darwin/arm64). Preflight catches this.

## Cross-Platform Notes

- **macOS (Docker Desktop)**: stats come from the LinuxKit VM, slightly delayed (~500ms).
- **Linux**: native cgroups, real-time.
- **Windows containers**: `--format` field names are the same, but `BlockIO` may show `0B / 0B` for Hyper-V isolated containers.
