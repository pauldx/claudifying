---
name: cf-tools-docker-compose-validate
description: "Validate a docker-compose.yml via `docker compose config --quiet` with structured error reporting. Trigger: /cf-tools-docker-compose-validate"
trigger: /cf-tools-docker-compose-validate
version: 1.0.0
---

# /cf-tools-docker-compose-validate

Catch broken `docker-compose.yml` files BEFORE running `up`. Uses `docker compose config` (v2 syntax, space) with `--quiet` to validate without echoing the merged config. Falls back to v1 `docker-compose` (hyphen) if v2 unavailable.

## Usage

```
/cf-tools-docker-compose-validate                          # validates ./docker-compose.yml
/cf-tools-docker-compose-validate path/to/compose.yml
/cf-tools-docker-compose-validate --print                  # also print resolved merged config
/cf-tools-docker-compose-validate --env-file=.env.staging  # validate with specific env
/cf-tools-docker-compose-validate -f base.yml -f prod.yml  # multi-file overlay
```

## What You Must Do When Invoked

### Step 1 — Locate compose file(s)

```bash
COMPOSE_FILE="${1:-docker-compose.yml}"

# Also accept docker-compose.yaml and compose.yml/compose.yaml (v2 names)
for candidate in "$COMPOSE_FILE" docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [ -f "$candidate" ]; then
    COMPOSE_FILE="$candidate"
    break
  fi
done

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "ERROR: No compose file found. Looked for: docker-compose.yml, compose.yml, etc."
  exit 1
fi
echo "Validating: $COMPOSE_FILE"
```

### Step 2 — Pick CLI variant (v2 preferred)

```bash
if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
  VERSION=$(docker compose version --short 2>/dev/null)
  echo "Using: docker compose v$VERSION (v2)"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
  VERSION=$(docker-compose --version | head -1)
  echo "Using: $VERSION (v1 fallback — consider upgrading)"
else
  echo "ERROR: Neither 'docker compose' nor 'docker-compose' is available."
  echo "Install Docker Desktop (includes compose v2) or:"
  echo "  brew install docker-compose      # macOS"
  echo "  apt install docker-compose-plugin # Debian/Ubuntu"
  exit 1
fi
```

### Step 3 — Validate

```bash
ARGS=( -f "$COMPOSE_FILE" )
[ -n "$ENV_FILE" ] && ARGS+=( --env-file "$ENV_FILE" )

# --quiet validates without dumping the rendered config to stdout
if "${COMPOSE[@]}" "${ARGS[@]}" config --quiet 2> /tmp/cv-err-$$.txt; then
  echo "✅ $COMPOSE_FILE is valid."
else
  echo "❌ Validation failed:"
  cat /tmp/cv-err-$$.txt
  echo
  echo "Common causes:"
  echo "  • Missing env var referenced as \${VAR} (no default)"
  echo "  • Invalid YAML indentation (tabs not allowed)"
  echo "  • Unknown top-level key (e.g. 'version' is deprecated in compose v2 spec, but still accepted)"
  echo "  • Service depends_on referencing a service name that doesn't exist"
  rm -f /tmp/cv-err-$$.txt
  exit 1
fi
rm -f /tmp/cv-err-$$.txt
```

### Step 4 — Optional: print merged config

```bash
if [ "$PRINT" = "1" ]; then
  echo "=== Resolved merged config ==="
  "${COMPOSE[@]}" "${ARGS[@]}" config
fi
```

## Output Contract

```
## docker compose validate

**File:**     <path>
**CLI:**      docker compose v2.24 | docker-compose v1.29 (fallback)
**Services:** <N> (web, db, redis, …)
**Result:**   ✅ valid | ❌ invalid
**Errors:**   <inline error block if invalid>
```

## Gotchas

- **`docker compose` vs `docker-compose`**: v2 is a Docker CLI plugin (space, no hyphen). v1 is a separate Python binary (hyphen). Behavior is mostly compatible but v1 is EOL — recommend upgrade.
- **`version:` field** is deprecated in compose spec v2+ but won't fail validation; it just emits a warning.
- **Env var interpolation**: `${VAR}` with no default and no value in `.env` produces an empty string in `config` but is NOT an error. Use `${VAR:?error msg}` to make it required.
- **`--quiet` only suppresses stdout**, errors still go to stderr. We capture both.
- **No daemon required**: `compose config` parses YAML locally; the Docker daemon is NOT contacted. Works even when Docker Desktop is stopped.
- **Daemon was NOT running** during skill auth (darwin/arm64). `compose config` still works — this is one of the few docker subcommands that doesn't need the daemon.

## Cross-Platform Notes

- **macOS / Windows**: Docker Desktop ships both `docker compose` (v2) and a `docker-compose` shim.
- **Linux**: install `docker-compose-plugin` package for v2. Standalone v1 binary still available via pip but discouraged.
- **CI runners** (GitHub Actions ubuntu-latest): v2 preinstalled since 2022.
