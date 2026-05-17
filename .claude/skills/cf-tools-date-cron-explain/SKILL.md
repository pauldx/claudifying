---
name: cf-tools-date-cron-explain
description: "Explain a cron expression in plain English; preview next N fire times. Trigger: /cf-tools-date-cron-explain"
trigger: /cf-tools-date-cron-explain
version: 1.0.0
---

# /cf-tools-date-cron-explain

Translate a 5-field (standard) or 6-field (with seconds, Quartz-style) cron expression into plain English, and list the next N times it will fire. Prefers `croniter` (PyPI) for accurate next-fire prediction; falls back to a hand-rolled describer that covers the common patterns.

## Usage

```
/cf-tools-date-cron-explain "*/15 * * * *"
/cf-tools-date-cron-explain "0 9 * * 1-5"
/cf-tools-date-cron-explain "30 14 * * 0" --count 10
/cf-tools-date-cron-explain "@daily"
```

Arguments:
1. Cron expression (quote it — `*` and `?` break unquoted shells)
2. `--count <N>` (default `5`) — how many upcoming fire times to list
3. `--tz <zone>` (default local) — IANA TZ for the fire-time preview

Aliases supported (translated before parsing):
- `@yearly` / `@annually` → `0 0 1 1 *`
- `@monthly` → `0 0 1 * *`
- `@weekly`  → `0 0 * * 0`
- `@daily` / `@midnight` → `0 0 * * *`
- `@hourly`  → `0 * * * *`
- `@reboot`  → NOT cron-time; flag and explain

## What You Must Do When Invoked

### Step 1 — Parse args + normalise

```bash
EXPR="$1"
shift
COUNT=5
TZ_NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --count) shift; COUNT="$1" ;;
    --tz) shift; TZ_NAME="$1" ;;
  esac
  shift
done

case "$EXPR" in
  @yearly|@annually) EXPR="0 0 1 1 *" ;;
  @monthly)          EXPR="0 0 1 * *" ;;
  @weekly)           EXPR="0 0 * * 0" ;;
  @daily|@midnight)  EXPR="0 0 * * *" ;;
  @hourly)           EXPR="0 * * * *" ;;
  @reboot)           echo "⚠️  '@reboot' fires once at system startup. Not a clock schedule."; exit 0 ;;
esac
```

### Step 2 — Describe in English (hand-rolled, covers ~80% cases)

```bash
python3 - "$EXPR" <<'PY'
import sys
expr = sys.argv[1].strip()
parts = expr.split()
if len(parts) not in (5, 6):
    print(f"ERROR: expected 5 or 6 fields, got {len(parts)}: {expr}", file=sys.stderr); sys.exit(1)

if len(parts) == 6:
    second, minute, hour, dom, month, dow = parts
    has_sec = True
else:
    minute, hour, dom, month, dow = parts
    second = None
    has_sec = False

DAYS = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
MONTHS = ["", "January","February","March","April","May","June",
          "July","August","September","October","November","December"]

def describe_field(f, name, mapping=None, mod=None):
    if f == "*":
        return f"every {name}"
    if f.startswith("*/"):
        return f"every {f[2:]} {name}{'s' if int(f[2:])>1 else ''}"
    if "-" in f and "/" not in f:
        a,b = f.split("-")
        if mapping:
            return f"from {mapping[int(a) % (mod or 99)]} through {mapping[int(b) % (mod or 99)]}"
        return f"from {name} {a} through {b}"
    if "," in f:
        items = f.split(",")
        if mapping:
            items = [mapping[int(x) % (mod or 99)] for x in items]
        return name + " " + ", ".join(items)
    if mapping and f.isdigit():
        return mapping[int(f) % (mod or 99)]
    return f"{name} {f}"

# Build pieces
time_piece = ""
if hour == "*" and minute == "*":
    time_piece = "every minute"
elif hour == "*" and minute.startswith("*/"):
    time_piece = f"every {minute[2:]} minutes"
elif hour == "*" and minute.isdigit():
    time_piece = f"at minute {minute} of every hour"
elif minute.isdigit() and hour.isdigit():
    time_piece = f"at {int(hour):02d}:{int(minute):02d}"
elif minute == "0" and hour.startswith("*/"):
    time_piece = f"every {hour[2:]} hours on the hour"
else:
    time_piece = f"at minute {minute}, hour {hour}"

day_piece = ""
if dow == "*" and dom == "*":
    day_piece = "every day"
elif dow != "*" and dom == "*":
    day_piece = "on " + describe_field(dow, "day", DAYS, 7)
elif dom != "*" and dow == "*":
    day_piece = describe_field(dom, "day-of-month")
else:
    day_piece = f"on day-of-month {dom} AND " + describe_field(dow, "day", DAYS, 7)

month_piece = ""
if month != "*":
    month_piece = " in " + describe_field(month, "month", MONTHS, 13)

print(f"Schedule: {time_piece} {day_piece}{month_piece}")
PY
```

### Step 3 — Compute next N fire times via `croniter` if available

```bash
if python3 -c "import croniter" 2>/dev/null; then
  python3 - "$EXPR" "$COUNT" "$TZ_NAME" <<'PY'
import sys, datetime
from croniter import croniter
expr, count, tz = sys.argv[1], int(sys.argv[2]), sys.argv[3]
try:
    from zoneinfo import ZoneInfo
    now = datetime.datetime.now(ZoneInfo(tz)) if tz else datetime.datetime.now().astimezone()
except Exception:
    now = datetime.datetime.now().astimezone()
itr = croniter(expr, now)
print(f"\nNext {count} fire times (TZ: {now.tzname()}):")
for _ in range(count):
    nxt = itr.get_next(datetime.datetime)
    print(f"  {nxt.strftime('%Y-%m-%d %H:%M:%S %Z')} ({nxt.strftime('%A')})")
PY
else
  echo ""
  echo "ℹ️  Install croniter for accurate next-fire predictions:"
  echo "    pip install croniter"
fi
```

## Output Contract

```
$ /cf-tools-date-cron-explain "0 9 * * 1-5"
Schedule: at 09:00 on from Monday through Friday

Next 5 fire times (TZ: PDT):
  2026-05-18 09:00:00 PDT (Monday)
  2026-05-19 09:00:00 PDT (Tuesday)
  2026-05-20 09:00:00 PDT (Wednesday)
  2026-05-21 09:00:00 PDT (Thursday)
  2026-05-22 09:00:00 PDT (Friday)
```

## Gotchas

- **5-field vs 6-field**: classic Unix cron is 5 fields (`m h dom mon dow`). Quartz / Spring `@Scheduled(cron=)` uses 6 (prepends seconds). AWS EventBridge uses 6 fields but with year as the last field. The skill assumes Unix-style; surface a warning if 6 fields are seen.
- **Day-of-month AND day-of-week** are OR'd by classic cron, NOT AND'd. `0 9 1 * 1` fires every Monday OR the 1st of any month. This trips up almost everyone. Skill says "AND" in description — fix this:
  ```
  on day-of-month {dom} OR on {dow}    # cron uses OR when both are restricted
  ```
- **`L` and `W` extensions**: `0 0 L * *` (last day of month), `0 0 1W * *` (nearest weekday to 1st) are Quartz/Vixie extensions, not standard. The hand-rolled describer skips these — croniter handles `L` only.
- **`?` placeholder** (Quartz) means "no specific value" — cron expects `*`. Reject with a hint.
- **Timezone ambiguity**: `cron` traditionally runs in the system TZ; modern schedulers (k8s CronJob, systemd) let you specify one. `--tz` here only affects the displayed next-fire times, not the expression semantics.
- **`*/N` math is FROM THE START of the field** — `*/15` on `minute` is `0,15,30,45`, not "every 15 min from now". Document.
- **DST jumps cause silent skips/dups** — at 2 AM spring-forward, jobs scheduled for 2:30 don't fire at all. Mention.

## Cross-Platform Notes

- **macOS / Linux**: python3 covers both. croniter optional but recommended.
- **Install croniter**: `pip install croniter` or `pip3 install --user croniter`.
- **Alternative explainers**: `crontab.guru` (web), `cron-descriptor` PyPI. This skill keeps it local-only.
- **systemd timers**: NOT cron syntax — those use OnCalendar expressions like `Mon..Fri 09:00`. Out of scope.
