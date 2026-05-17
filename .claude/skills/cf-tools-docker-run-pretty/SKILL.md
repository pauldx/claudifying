---
name: cf-tools-docker-run-pretty
description: "Wrap `docker run` with sensible defaults (--rm -it, cwd mount, named container, host UID). Trigger: /cf-tools-docker-run-pretty"
trigger: /cf-tools-docker-run-pretty
version: 1.0.0
---

# /cf-tools-docker-run-pretty

Most `docker run` invocations need the same boilerplate: `--rm` (auto-cleanup), `-it` (interactive TTY), cwd mounted, deterministic container name, host user ID to avoid root-owned output. This skill builds that command from a short signature.

## Usage

```
/cf-tools-docker-run-pretty <image> [cmd...]
/cf-tools-docker-run-pretty node:20 npm test
/cf-tools-docker-run-pretty python:3.12 python script.py
/cf-tools-docker-run-pretty ubuntu bash
/cf-tools-docker-run-pretty --name=mybuild --port=3000 node:20 npm run dev
/cf-tools-docker-run-pretty --no-mount alpine echo hello   # skip cwd mount
```

Optional flags (must precede image):
- `--name=<n>` — container name (default: derived from image, e.g. `node-20-run`)
- `--port=<p>` — publish port to host (`-p p:p`)
- `--env=KEY=VAL` — env var (repeatable)
- `--no-mount` — don't mount cwd
- `--root` — run as root inside (default: host UID:GID)
- `--workdir=<path>` — container workdir (default `/work`)

## What You Must Do When Invoked

### Step 1 — Preflight

```bash
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker CLI not installed."; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: Docker daemon not running."; exit 1; }
```

### Step 2 — Build the command

```bash
IMAGE="<first non-flag arg>"
CMD_ARGS=("<remaining args>")

# Default name: sanitize image, append -run
DEFAULT_NAME=$(echo "$IMAGE" | tr ':/' '-' | tr -cd 'A-Za-z0-9-')-run
CONTAINER_NAME="${NAME:-$DEFAULT_NAME}"

# Default user: host UID:GID unless --root
if [ "$AS_ROOT" = "1" ]; then
  USER_FLAG=()
else
  USER_FLAG=( --user "$(id -u):$(id -g)" )
fi

# Default mount: cwd → /work unless --no-mount
WORKDIR="${WORKDIR:-/work}"
if [ "$NO_MOUNT" = "1" ]; then
  MOUNT_FLAG=()
else
  MOUNT_FLAG=( -v "$(pwd):${WORKDIR}" -w "${WORKDIR}" )
fi

# Port
PORT_FLAG=()
[ -n "$PORT" ] && PORT_FLAG=( -p "${PORT}:${PORT}" )

# Env (repeatable)
ENV_FLAGS=()
for kv in "${ENV_VARS[@]}"; do
  ENV_FLAGS+=( -e "$kv" )
done

# Pre-empt name collision
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "Container '$CONTAINER_NAME' already exists; removing..."
  docker rm -f "$CONTAINER_NAME" >/dev/null
fi

FULL=(docker run --rm -it \
  --name "$CONTAINER_NAME" \
  "${USER_FLAG[@]}" \
  "${MOUNT_FLAG[@]}" \
  "${PORT_FLAG[@]}" \
  "${ENV_FLAGS[@]}" \
  "$IMAGE" "${CMD_ARGS[@]}")
```

### Step 3 — Show and run

```bash
echo "Running: ${FULL[*]}"
echo
"${FULL[@]}"
```

## Output Contract

```
## docker run (pretty)

**Image:**     <image>
**Container:** <name>
**Mount:**     $(pwd) → /work
**User:**      <uid:gid> (host) | root (--root)
**Ports:**     <p:p> | none
**Command:**   <cmd...>
**Exit:**      <code>
```

## Gotchas

- **`-it` and non-TTY**: in CI, `-it` fails with "input device is not a TTY". Detect with `[ -t 0 ]` and drop `-i -t` if not connected to a terminal.
- **`--user $(id -u):$(id -g)` breaks images that require root** (e.g. Alpine `apk add`). Use `--root` for those.
- **Mounting cwd over Docker Desktop file sharing on macOS** is SLOW (~10× slower than native FS). For perf-critical work use named volumes or enable VirtioFS.
- **SELinux on RHEL/Fedora**: bind mounts need `:Z` suffix (`-v $(pwd):/work:Z`) or permission denied. Document but don't auto-add (breaks Linux without SELinux).
- **Image must exist locally OR be pullable**: first run with new image triggers `docker pull`, can hang for minutes on large images.
- **Daemon not running** during skill auth (darwin/arm64). Preflight catches this.

## Cross-Platform Notes

- **macOS**: Docker Desktop or OrbStack. OrbStack is faster but identical CLI.
- **Linux**: native, no perf penalty for bind mounts.
- **Windows**: use `${PWD}` (PowerShell) or `%cd%` (CMD) for the mount source. WSL2 backend recommended.
