---
name: cf-tools-hash-uuid
description: "Generate UUIDs — v4 (random), v7 (time-ordered), v5 (namespace-based). Bulk N supported. Trigger: /cf-tools-hash-uuid"
trigger: /cf-tools-hash-uuid
version: 1.0.0
---

# /cf-tools-hash-uuid

Generate one or many UUIDs in v4 (default), v7 (time-sortable, RFC 9562), or v5 (namespace + name → deterministic). Useful for seeding fixtures, ID columns, idempotency keys, and feature flags.

## Usage

```
/cf-tools-hash-uuid                            # one v4
/cf-tools-hash-uuid -n 10                      # 10 v4s
/cf-tools-hash-uuid --version 7                # one v7 (time-ordered)
/cf-tools-hash-uuid --version 5 --ns dns --name example.com
/cf-tools-hash-uuid --upper                    # uppercase hex
/cf-tools-hash-uuid --no-hyphens               # strip hyphens
```

Arguments:
- `-n <N>` (default `1`) — how many to generate
- `--version <4|5|7>` (default `4`)
- `--ns <dns|url|oid|x500|UUID>` — namespace for v5
- `--name <string>` — name for v5
- `--upper` — uppercase
- `--no-hyphens` — strip the `-` separators (32 hex chars)

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
N=1
VER=4
NS=""
NAME=""
UPPER=0
NOHYPH=0
while [ $# -gt 0 ]; do
  case "$1" in
    -n) shift; N="$1" ;;
    --version) shift; VER="$1" ;;
    --ns) shift; NS="$1" ;;
    --name) shift; NAME="$1" ;;
    --upper) UPPER=1 ;;
    --no-hyphens) NOHYPH=1 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
  shift
done
```

### Step 2 — Generate per version

The macOS `uuidgen` only produces v4. v5 and v7 need python (stdlib `uuid` covers v3/v4/v5 since 3.0; v7 lives in Python 3.14+, but a 60-line implementation works everywhere).

```bash
case "$VER" in
  4)
    if command -v uuidgen >/dev/null 2>&1; then
      for i in $(seq 1 "$N"); do uuidgen; done
    else
      python3 -c "import uuid;[print(uuid.uuid4()) for _ in range($N)]"
    fi
    ;;
  5)
    if [ -z "$NS" ] || [ -z "$NAME" ]; then
      echo "ERROR: --ns and --name required for v5" >&2; exit 1
    fi
    python3 - "$NS" "$NAME" "$N" <<'PY'
import sys, uuid
ns_in, name, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
ns_map = {
    "dns":  uuid.NAMESPACE_DNS,
    "url":  uuid.NAMESPACE_URL,
    "oid":  uuid.NAMESPACE_OID,
    "x500": uuid.NAMESPACE_X500,
}
ns = ns_map.get(ns_in.lower()) or uuid.UUID(ns_in)
for _ in range(n):
    print(uuid.uuid5(ns, name))
PY
    ;;
  7)
    # v7: 48-bit Unix ms timestamp + 4 version bits + 12 random + 2 variant + 62 random
    python3 - "$N" <<'PY'
import sys, os, time
n = int(sys.argv[1])
for _ in range(n):
    ts_ms = int(time.time() * 1000) & 0xFFFFFFFFFFFF
    rand_a = int.from_bytes(os.urandom(2), "big") & 0x0FFF      # 12 bits
    rand_b = int.from_bytes(os.urandom(8), "big") & 0x3FFFFFFFFFFFFFFF  # 62 bits
    # Assemble
    hi = (ts_ms << 16) | (0x7 << 12) | rand_a   # 64 bits: ts(48)|ver(4)|rand_a(12)
    lo = (0b10 << 62) | rand_b                  # 64 bits: variant(2)|rand_b(62)
    h = f"{hi:016x}{lo:016x}"
    print(f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}")
PY
    ;;
  *) echo "ERROR: unsupported version $VER" >&2; exit 1 ;;
esac \
| { [ "$UPPER" -eq 1 ] && tr 'a-f' 'A-F' || cat; } \
| { [ "$NOHYPH" -eq 1 ] && tr -d '-' || cat; }
```

### Step 3 — Print

The pipeline above already prints; no further work needed.

## Output Contract

```
$ /cf-tools-hash-uuid -n 3
0a1b2c3d-4e5f-46a7-8b9c-0d1e2f3a4b5c
1b2c3d4e-5f6a-47b8-9c0d-1e2f3a4b5c6d
2c3d4e5f-6a7b-48c9-0d1e-2f3a4b5c6d7e

$ /cf-tools-hash-uuid --version 7 -n 2
018f3a1d-04b8-7a3c-9e21-7f6c5b8d2a01
018f3a1d-04b9-7c4d-a83e-1c7d4e9a2b03

$ /cf-tools-hash-uuid --version 5 --ns dns --name example.com
cfbff0d1-9375-5685-968a-48ce8b50c3da     # always the same
```

## Gotchas

- **v4 is NOT sortable** — inserts into an indexed UUID column scatter writes across pages. Use v7 for high-write tables.
- **v7 in Python stdlib only landed in 3.14** — hand-rolled implementation above works on 3.6+. Avoid `uuid6` PyPI library for production until you've verified its variant bit handling.
- **v5 collision risk = SHA-1 collision risk** = practically zero for distinct names, but v5 from attacker-supplied names CAN be precomputed. Don't use v5 as an unguessable token.
- **`uuidgen` flag differences**: macOS prints uppercase, Linux util-linux prints lowercase. The skill normalises to lowercase by default.
- **`--no-hyphens` breaks Postgres `uuid` type** — Postgres requires the canonical form. Use this only for compact storage in other systems.
- **Cryptographic randomness**: `os.urandom` is OS CSPRNG-backed; `uuid.uuid4()` uses it under the hood. Both safe for security tokens. Don't substitute `random.random()`.

## Cross-Platform Notes

- **macOS**: `uuidgen` ships. python3 ships in /usr/bin/python3 (stub) — install via `brew install python` if `python3 -c "import uuid"` fails.
- **Linux**: `uuidgen` in `util-linux`. python3 universal.
- **GNU `uuid`**: the rare `ossp-uuid` tool can produce v1/v3/v5 directly; if you have it, the python paths above are optional but kept for portability.
- **Bulk N**: skill should refuse `n > 10000` without `--force` to avoid runaway scripts.
