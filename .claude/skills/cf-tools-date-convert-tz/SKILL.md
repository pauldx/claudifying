---
name: cf-tools-date-convert-tz
description: "Convert an ISO timestamp from one IANA timezone to another. Trigger: /cf-tools-date-convert-tz"
trigger: /cf-tools-date-convert-tz
version: 1.0.0
---

# /cf-tools-date-convert-tz

Take a timestamp + source TZ and re-render it in one or more destination TZs. Handles DST, half-hour zones (`Asia/Kolkata`, `Australia/Adelaide`), and Nepal (`Asia/Kathmandu`, +05:45). Uses python `zoneinfo` (stdlib, Python 3.9+) so it's zero-install on any modern system.

## Usage

```
/cf-tools-date-convert-tz "2026-05-17T10:00:00" UTC America/New_York
/cf-tools-date-convert-tz "2026-05-17T10:00:00" UTC Asia/Tokyo Europe/London Asia/Kolkata
/cf-tools-date-convert-tz "now" UTC America/New_York
```

Arguments:
1. Timestamp — ISO 8601 (`YYYY-MM-DDTHH:MM:SS`) OR `now`
2. Source TZ — IANA zone name (e.g. `UTC`, `America/Los_Angeles`)
3. One or more destination TZs

## What You Must Do When Invoked

### Step 1 — Validate args

```bash
TS="$1"
SRC="$2"
shift 2
DSTS=("$@")

if [ -z "$TS" ] || [ -z "$SRC" ] || [ ${#DSTS[@]} -eq 0 ]; then
  echo "USAGE: cf-tools-date-convert-tz <timestamp|now> <source-tz> <dest-tz>..." >&2
  exit 1
fi
```

### Step 2 — Convert via python `zoneinfo`

```bash
python3 - "$TS" "$SRC" "${DSTS[@]}" <<'PY'
import sys, datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

ts, src, *dsts = sys.argv[1:]
try:
    src_zi = ZoneInfo(src)
except ZoneInfoNotFoundError:
    print(f"ERROR: unknown source TZ: {src}", file=sys.stderr); sys.exit(1)

if ts == "now":
    dt = datetime.datetime.now(tz=src_zi)
else:
    # Strip trailing Z if user pasted one (means UTC)
    raw = ts.rstrip("Z")
    # Try common ISO variants
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            dt = datetime.datetime.strptime(raw, fmt).replace(tzinfo=src_zi)
            break
        except ValueError:
            continue
    else:
        print(f"ERROR: unrecognised timestamp format: {ts}", file=sys.stderr); sys.exit(1)

print(f"Source: {dt.isoformat()} ({src})")
print()
print(f"{'ZONE':<28} {'LOCAL':<26} {'OFFSET':<8} {'NAME'}")
print("-" * 80)
for d in dsts:
    try:
        zi = ZoneInfo(d)
    except ZoneInfoNotFoundError:
        print(f"{d:<28} ERROR: unknown TZ")
        continue
    local = dt.astimezone(zi)
    offset = local.strftime("%z")
    offset_fmt = f"{offset[:3]}:{offset[3:]}"
    name = local.tzname()
    print(f"{d:<28} {local.strftime('%Y-%m-%d %H:%M:%S'):<26} {offset_fmt:<8} {name}")
PY
```

## Output Contract

```
Source: 2026-05-17T10:00:00+00:00 (UTC)

ZONE                         LOCAL                      OFFSET   NAME
--------------------------------------------------------------------------------
America/New_York             2026-05-17 06:00:00        -04:00   EDT
Asia/Tokyo                   2026-05-17 19:00:00        +09:00   JST
Europe/London                2026-05-17 11:00:00        +01:00   BST
Asia/Kolkata                 2026-05-17 15:30:00        +05:30   IST
Asia/Kathmandu               2026-05-17 15:45:00        +05:45   +0545
```

## Gotchas

- **`zoneinfo` requires Python 3.9+.** Older systems: `pip install backports.zoneinfo` and `from backports.zoneinfo import ZoneInfo` — not covered by this skill.
- **Windows lacks the system tz database** by default. Install `tzdata` package: `pip install tzdata`. Skill should fail with a clear message rather than silently use UTC.
- **DST transitions are non-monotonic** — passing a timestamp that falls in the "spring forward" gap (e.g. `2026-03-08T02:30:00` in US) is technically undefined; `zoneinfo` resolves it as if DST already started. Document this.
- **Half-hour and 45-minute zones**: skill must show full HH:MM offsets, not just hours. The format `%z` returns `+0530`; the skill reformats to `+05:30` for readability.
- **Three-letter abbreviations (PST, EST, IST)** are AMBIGUOUS — `IST` is India Standard Time AND Israel Standard Time AND Irish Standard Time. The skill rejects abbreviations; require IANA names.
- **Historical dates pre-1970** have erratic offsets per the tz database's "before standardisation" estimates. Don't trust to-the-second accuracy for old dates.
- **`now` is the source-TZ wallclock** — passing `now` with `--source UTC` is fine; passing `now America/New_York` returns NY's current wallclock and converts onward.

## Cross-Platform Notes

- **macOS**: python3 via Homebrew or system; tz data in `/var/db/timezone/zoneinfo`.
- **Linux**: tz data in `/usr/share/zoneinfo`. Universal.
- **`TZ=<zone> date`** is a shell-only alternative for simple cases (`TZ=Asia/Tokyo date`). Doesn't handle the "convert this specific timestamp" use case well — that's why this skill uses python.
- **List zones**: `python3 -c "import zoneinfo;print('\n'.join(sorted(zoneinfo.available_timezones())))"` for tab-completion sources.
