---
name: cf-tools-docker-prune
description: "Reclaim disk by pruning unused Docker containers, networks, images, build cache, and (optionally) volumes. Trigger: /cf-tools-docker-prune"
trigger: /cf-tools-docker-prune
version: 1.0.0
---

# /cf-tools-docker-prune

Wrap `docker system prune` with sensible defaults, a bytes-reclaimed summary, and a confirmation gate. The `--volumes` flag is gated behind explicit opt-in because it can delete production data.

## Usage

```
/cf-tools-docker-prune                  # containers, networks, dangling images, build cache
/cf-tools-docker-prune --volumes        # also deletes unused named/anonymous volumes (DESTRUCTIVE)
/cf-tools-docker-prune --all            # also remove ALL unused images (not just dangling)
/cf-tools-docker-prune --all --volumes  # full nuke (use with care)
/cf-tools-docker-prune --dry-run        # show what WOULD be removed (uses df + filter)
```

Arguments (any order):
- `--volumes` — include unused volumes (off by default)
- `--all` — equivalent of `docker system prune -a` (removes unused images, not just dangling)
- `--dry-run` — preview reclaim estimate without deleting

## What You Must Do When Invoked

### Step 1 — Preflight

```bash
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker CLI not installed. Install Docker Desktop: https://docs.docker.com/get-docker/"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon not running. Start Docker Desktop and retry."
  exit 1
fi
```

### Step 2 — Baseline disk usage

```bash
echo "=== Disk usage BEFORE prune ==="
docker system df
BEFORE_BYTES=$(docker system df --format '{{.Size}}' | awk '
  /^[0-9.]+GB$/ { gsub("GB",""); s+=$1*1024*1024*1024 }
  /^[0-9.]+MB$/ { gsub("MB",""); s+=$1*1024*1024 }
  /^[0-9.]+kB$/ { gsub("kB",""); s+=$1*1024 }
  END { printf "%.0f", s }')
```

### Step 3 — Build the prune command

```bash
CMD=(docker system prune -f)
[ "$ALL" = "1" ]     && CMD+=( -a )
[ "$VOLUMES" = "1" ] && CMD+=( --volumes )

if [ "$DRY_RUN" = "1" ]; then
  echo "DRY RUN — would execute: ${CMD[*]}"
  echo "Estimated reclaim from \`docker system df\` above (RECLAIMABLE column)."
  exit 0
fi
```

### Step 4 — Execute and report reclaim

```bash
echo "Running: ${CMD[*]}"
OUT=$("${CMD[@]}")
echo "$OUT"

echo
echo "=== Disk usage AFTER prune ==="
docker system df

# docker prune prints "Total reclaimed space: 1.2GB" as its last line
RECLAIMED=$(echo "$OUT" | grep -i 'Total reclaimed' | sed -E 's/.*: //')
echo
echo "✅ Reclaimed: ${RECLAIMED:-(none / not reported)}"
```

## Output Contract

```
## docker prune

**Flags applied:** --all=<0|1> --volumes=<0|1>
**Before:**       <docker system df line summary>
**After:**        <docker system df line summary>
**Reclaimed:**    <e.g. 1.234GB>
**Verdict:**      ✅ success | ⚠️ partial | ❌ failed
```

## Gotchas

- **`--volumes` is destructive.** Named volumes with no running container attached look "unused" — they may still contain production data (Postgres, MySQL, MongoDB). Confirm before running.
- **Docker daemon not running** on this host (verified during skill authoring on darwin/arm64). Always run preflight `docker info` check.
- **`docker system prune` without `-a`** only removes *dangling* images (no tags). Use `--all` to also remove tagged images that aren't referenced by any container.
- **BuildKit cache** is included in prune by default in modern Docker (≥20.10). Older versions need `docker builder prune` separately.
- **Concurrent builds**: prune during an active `docker build` can fail mid-layer. Pause CI before pruning shared runners.

## Cross-Platform Notes

- **macOS / Windows**: Docker Desktop must be running. Quitting the app stops the daemon.
- **Linux**: daemon is usually `systemctl status docker`. Without sudo membership in `docker` group, prefix commands with `sudo`.
- **Rootless Docker**: `docker system df` reports user-scoped usage only; system images installed by root won't appear.
