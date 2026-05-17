---
name: cf-tools-docker-cleanup-images
description: "Remove dangling and untagged Docker images and report disk freed. Trigger: /cf-tools-docker-cleanup-images"
trigger: /cf-tools-docker-cleanup-images
version: 1.0.0
---

# /cf-tools-docker-cleanup-images

Targeted image cleanup. Removes `<none>:<none>` images (dangling — leftover from rebuilds) and optionally untagged-but-referenced images. Less aggressive than `docker system prune -a`; will not delete tagged images that are unused.

## Usage

```
/cf-tools-docker-cleanup-images              # remove dangling only (safe)
/cf-tools-docker-cleanup-images --untagged   # also remove non-dangling untagged
/cf-tools-docker-cleanup-images --older-than=7d  # only images older than N
/cf-tools-docker-cleanup-images --dry-run    # list candidates without removing
```

Arguments:
- `--untagged` — include images that lost their tag but are not dangling
- `--older-than=<duration>` — only images older than N (e.g. `24h`, `7d`, `720h`)
- `--dry-run` — print candidates; don't delete

## What You Must Do When Invoked

### Step 1 — Preflight

```bash
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker CLI not installed."; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: Docker daemon not running. Start Docker Desktop."; exit 1; }
```

### Step 2 — Snapshot baseline size

```bash
BEFORE=$(docker images --format '{{.Size}}' | awk '
  /GB$/ { gsub("GB",""); s+=$1*1024 }
  /MB$/ { gsub("MB",""); s+=$1 }
  /kB$/ { gsub("kB",""); s+=$1/1024 }
  END { printf "%.1f", s }')
echo "Total image size before: ${BEFORE} MB"
```

### Step 3 — Find dangling images

```bash
DANGLING=$(docker images -f "dangling=true" -q)
DANGLING_COUNT=$(echo "$DANGLING" | grep -c . || echo 0)
echo "Dangling images: $DANGLING_COUNT"

if [ "$DRY_RUN" = "1" ]; then
  echo "DRY RUN — would remove:"
  docker images -f "dangling=true" --format 'table {{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}'
  exit 0
fi
```

### Step 4 — Remove

```bash
if [ "$DANGLING_COUNT" -gt 0 ]; then
  echo "Removing dangling images..."
  # docker image prune is the official, idempotent way
  if [ -n "$OLDER_THAN" ]; then
    docker image prune -f --filter "dangling=true" --filter "until=${OLDER_THAN}"
  else
    docker image prune -f
  fi
fi

if [ "$UNTAGGED" = "1" ]; then
  echo "Looking for non-dangling untagged images..."
  # untagged-but-not-dangling: images where ALL tags were removed but layers still referenced
  UNTAGGED_IDS=$(docker images --format '{{.ID}} {{.Repository}}' | awk '$2=="<none>" {print $1}' | sort -u)
  if [ -n "$UNTAGGED_IDS" ]; then
    echo "$UNTAGGED_IDS" | xargs -I{} docker rmi {} 2>/dev/null || true
  fi
fi
```

### Step 5 — Report reclaim

```bash
AFTER=$(docker images --format '{{.Size}}' | awk '
  /GB$/ { gsub("GB",""); s+=$1*1024 }
  /MB$/ { gsub("MB",""); s+=$1 }
  /kB$/ { gsub("kB",""); s+=$1/1024 }
  END { printf "%.1f", s }')
RECLAIMED=$(awk -v b="$BEFORE" -v a="$AFTER" 'BEGIN { printf "%.1f", b-a }')
echo
echo "✅ Cleanup complete. Reclaimed: ${RECLAIMED} MB (before: ${BEFORE} MB → after: ${AFTER} MB)"
```

## Output Contract

```
## docker image cleanup

**Before:**     <X> MB across <N> images
**Removed:**    <M> dangling + <K> untagged
**After:**      <Y> MB across <N-M-K> images
**Reclaimed:**  <X-Y> MB
**Result:**     ✅ success
```

## Gotchas

- **Dangling vs untagged**: dangling = `<none>:<none>` with no parent. Untagged = had a tag, lost it (e.g. `docker pull` of same tag with new digest orphaned the old layers). The latter is often still wanted (rollback).
- **Cannot remove "image in use" errors**: an image referenced by a container (even stopped) cannot be deleted. Run `/cf-tools-docker-prune` first to remove stopped containers, OR use `docker rmi -f` (DANGEROUS — invalidates the container).
- **`docker image prune --filter "until=..."`** accepts Go duration syntax: `24h`, `720h` (= 30d). NOT `7d` directly — convert to hours.
- **Disk reclaim ≠ size sum**: shared layers count multiple times in `docker images` size column. Actual disk freed is usually less than the math suggests. Trust `docker system df` for ground truth.
- **Docker daemon not running** during skill auth verification (darwin/arm64). Preflight catches this.

## Cross-Platform Notes

- **macOS / Windows**: Docker Desktop's VM has its own filesystem; reclaim shows up in Docker Desktop disk usage, not host `df`.
- **Linux**: images live in `/var/lib/docker/`. Need `sudo` if user not in `docker` group.
