---
name: cf-tools-k8s-get-events
description: "Show Kubernetes events sorted chronologically (last N minutes) across a namespace or cluster. Trigger: /cf-tools-k8s-get-events"
trigger: /cf-tools-k8s-get-events
version: 1.0.0
---

# /cf-tools-k8s-get-events

`kubectl get events` defaults to unsorted output and an arbitrary recent window. This skill sorts by `lastTimestamp`, filters to the last N minutes, and optionally restricts by type (Warning), object, or namespace.

## Usage

```
/cf-tools-k8s-get-events                            # current ns, last 15m
/cf-tools-k8s-get-events --since=1h
/cf-tools-k8s-get-events --namespace=kube-system
/cf-tools-k8s-get-events --all-namespaces
/cf-tools-k8s-get-events --warnings                 # type=Warning only
/cf-tools-k8s-get-events --for=pod/web-abc123       # events about one object
/cf-tools-k8s-get-events --watch                    # stream new events
```

Arguments:
- `--since=<duration>` (default `15m`) — filter by `lastTimestamp` (client-side)
- `--namespace=<ns>` (default: current context's)
- `--all-namespaces` (or `-A`)
- `--warnings` — only `type=Warning`
- `--for=<kind/name>` — events involving one object
- `--watch` — live stream

## What You Must Do When Invoked

### Step 1 — Preflight

```bash
command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl not installed."
  echo "Install: brew install kubectl  | apt install kubectl"
  exit 1
}
kubectl version --client >/dev/null 2>&1 || { echo "ERROR: kubectl broken."; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "ERROR: no cluster reachable."; exit 1; }
```

### Step 2 — Build query

```bash
ARGS=(get events --sort-by=.lastTimestamp)

if [ "$ALL_NS" = "1" ]; then
  ARGS+=( -A )
elif [ -n "$NAMESPACE" ]; then
  ARGS+=( -n "$NAMESPACE" )
fi

if [ "$WARNINGS" = "1" ]; then
  ARGS+=( --field-selector type=Warning )
fi

if [ -n "$FOR" ]; then
  # --for is not a real kubectl flag; emulate with field selector
  KIND="${FOR%%/*}"
  NAME="${FOR##*/}"
  ARGS+=( --field-selector "involvedObject.kind=${KIND^},involvedObject.name=${NAME}" )
fi

[ "$WATCH" = "1" ] && ARGS+=( --watch )
```

### Step 3 — Execute and post-filter by --since

```bash
SINCE="${SINCE:-15m}"

if [ "$WATCH" = "1" ]; then
  echo "Streaming events (Ctrl-C to exit)..."
  kubectl "${ARGS[@]}"
  exit
fi

# Convert --since to seconds for client-side filter
case "$SINCE" in
  *h*m*) SECS=$(echo "$SINCE" | sed -E 's/([0-9]+)h([0-9]+)m/\1*3600+\2*60/' | bc) ;;
  *h)    SECS=$(echo "${SINCE%h}*3600" | bc) ;;
  *m)    SECS=$(echo "${SINCE%m}*60" | bc) ;;
  *s)    SECS=${SINCE%s} ;;
  *)     SECS=900 ;;  # default 15m
esac

CUTOFF=$(date -u -v -${SECS}S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "-${SECS} seconds" +"%Y-%m-%dT%H:%M:%SZ")

# Get events as JSON, filter by timestamp, render table
kubectl "${ARGS[@]}" -o json | python3 - "$CUTOFF" <<'PY'
import sys, json
from datetime import datetime
cutoff = sys.argv[1]
data = json.load(sys.stdin)
rows = []
for e in data.get("items", []):
    ts = e.get("lastTimestamp") or e.get("eventTime") or ""
    if ts < cutoff:
        continue
    rows.append((
        ts,
        e.get("type", ""),
        e.get("reason", ""),
        f"{e.get('involvedObject', {}).get('kind','')}/{e.get('involvedObject', {}).get('name','')}",
        (e.get("message", "") or "")[:80]
    ))
print(f"{'LAST-SEEN':<22} {'TYPE':<8} {'REASON':<22} {'OBJECT':<40} MESSAGE")
for r in rows:
    print(f"{r[0]:<22} {r[1]:<8} {r[2]:<22} {r[3]:<40} {r[4]}")
print(f"\nTotal: {len(rows)} events")
PY
```

## Output Contract

```
## kubectl events (sorted)

**Namespace:** <ns>|all
**Window:**    last <duration>
**Filter:**    --warnings | --for=<obj> | none
**Count:**     <N>

LAST-SEEN              TYPE     REASON                 OBJECT                                   MESSAGE
2024-01-15T10:00:00Z   Warning  FailedScheduling       Pod/web-abc                              0/3 nodes...
...
```

## Gotchas

- **Events expire fast**: kube-apiserver garbage-collects events after ~1h by default (configurable per cluster via `--event-ttl`). `--since=24h` may return nothing on a busy cluster.
- **`--sort-by=.lastTimestamp` ascending only** — newest at the bottom. Pipe to `tac` if you want newest-first.
- **`eventTime` vs `lastTimestamp`**: newer event API (`events.k8s.io/v1`) uses `eventTime` + `series`; older `core/v1` uses `firstTimestamp`/`lastTimestamp`. Our JSON post-filter checks both.
- **Field selector limitations**: kube-apiserver only allows certain fields in `--field-selector`. Some clusters reject `involvedObject.kind` filtering — fallback is full JSON + jq/python filter.
- **Date math**: `date -v -Ns` is BSD/macOS; `date -d "-N seconds"` is GNU/Linux. Skill detects with `||`.
- **No cluster during skill auth** — preflight is the safety net.

## Cross-Platform Notes

- **macOS**: BSD `date` syntax (`-v -15M`).
- **Linux**: GNU `date` syntax (`-d "-15 minutes"`).
- **WSL2**: GNU `date` (Linux behavior).
- **Old clusters (<1.19)**: `kubectl events` subcommand doesn't exist — fall back to `kubectl get events` (covered here).
