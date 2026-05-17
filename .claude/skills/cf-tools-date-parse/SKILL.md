---
name: cf-tools-date-parse
description: "Parse 'now', 'next monday', 'yesterday 3pm', or ISO dates into canonical ISO 8601. Trigger: /cf-tools-date-parse"
trigger: /cf-tools-date-parse
version: 1.0.0
---

# /cf-tools-date-parse

Take a human-friendly date phrase (or ISO timestamp) and emit ISO 8601 in UTC and local TZ. Primary engine is BSD/GNU `date`; falls back to python `dateparser` for natural-language input like `"next monday"`, `"yesterday 3pm"`, `"3 weeks ago"`.

## Usage

```
/cf-tools-date-parse "now"
/cf-tools-date-parse "2026-05-17"
/cf-tools-date-parse "next monday"
/cf-tools-date-parse "yesterday 3pm"
/cf-tools-date-parse "2026-05-17T14:30:00" --tz America/New_York
```

Arguments:
1. Date/time phrase (required, quote multi-word phrases)
2. `--tz <zone>` (optional) — interpret the input in this zone

## What You Must Do When Invoked

### Step 1 — Try the cheap path: BSD/GNU `date`

```bash
INPUT="$1"
shift
TZ_OVERRIDE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tz) shift; TZ_OVERRIDE="$1" ;;
  esac
  shift
done

ISO=""

# Case A: "now"
if [ "$INPUT" = "now" ]; then
  ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
fi

# Case B: looks like ISO (YYYY-MM-DD optionally with Thh:mm:ss[Z])
if [ -z "$ISO" ] && echo "$INPUT" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}([T ][0-9]{2}:[0-9]{2}(:[0-9]{2})?)?Z?$'; then
  # Try BSD `date -j -f`
  for FMT in "%Y-%m-%dT%H:%M:%SZ" "%Y-%m-%dT%H:%M:%S" "%Y-%m-%d %H:%M:%S" "%Y-%m-%d"; do
    OUT=$(date -j -f "$FMT" "$INPUT" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) && { ISO="$OUT"; break; }
  done
  # GNU fallback
  [ -z "$ISO" ] && ISO=$(date -d "$INPUT" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
fi
```

### Step 2 — Try GNU `date -d` for relative phrases (Linux)

```bash
if [ -z "$ISO" ]; then
  ISO=$(date -d "$INPUT" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
fi
```

### Step 3 — Fall back to python dateparser

```bash
if [ -z "$ISO" ]; then
  if python3 -c "import dateparser" 2>/dev/null; then
    ISO=$(python3 - "$INPUT" "$TZ_OVERRIDE" <<'PY'
import sys, dateparser
text, tz = sys.argv[1], sys.argv[2] or None
settings = {"RETURN_AS_TIMEZONE_AWARE": True}
if tz: settings["TIMEZONE"] = tz
dt = dateparser.parse(text, settings=settings)
if not dt:
    sys.exit(1)
import datetime
print(dt.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)
  else
    echo "ERROR: could not parse '$INPUT' with date(1). Install dateparser for natural language:" >&2
    echo "       pip install dateparser" >&2
    exit 1
  fi
fi
```

### Step 4 — Render in multiple useful formats

```bash
LOCAL_TZ=$(date +%Z)
EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ISO" +%s 2>/dev/null \
     || date -d "$ISO" +%s 2>/dev/null)
LOCAL_ISO=$(date -r "$EPOCH" +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null \
         || date -d "@$EPOCH" +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null)

echo "Input:       $INPUT"
echo "UTC:         $ISO"
echo "Local ($LOCAL_TZ): $LOCAL_ISO"
echo "Epoch:       $EPOCH"
echo "Day of week: $(date -r "$EPOCH" +%A 2>/dev/null || date -d "@$EPOCH" +%A)"
```

## Output Contract

```
Input:       next monday
UTC:         2026-05-18T00:00:00Z
Local (PDT): 2026-05-17T17:00:00-0700
Epoch:       1779465600
Day of week: Monday
```

## Gotchas

- **macOS `date` does not accept `-d "yesterday"`** — that's a GNU extension. The skill probes BSD-`-j -f`, then GNU `-d`, then python `dateparser`.
- **Two-digit years** (`5/17/26`) are ambiguous. `dateparser` defaults to YMD-priority via the input string format; document the user should prefer ISO when possible.
- **DST boundary days** — `"yesterday 3pm"` evaluated near spring-forward gives a non-existent local time. `dateparser` shifts forward; document the surprise.
- **Empty string from python**: dateparser returns `None` for unparseable; skill exits 1 cleanly.
- **`--tz` only affects input interpretation** — output is always UTC + local. To re-render in arbitrary TZ, use `/cf-tools-date-convert-tz`.
- **`now` is ALWAYS the wall clock at invocation**, not the user's local time if they're SSH'd into a server with different TZ. The skill uses the host's TZ; mention this.
- **Locale-affected day names** — `date +%A` returns localized day names (`lundi`, `Montag`). For consistency, the skill sets nothing; if reproducibility matters, prepend `LC_ALL=C`.

## Cross-Platform Notes

- **macOS**: BSD `date`. `gdate` (GNU) available via `brew install coreutils` and recommended for natural language.
- **Linux**: GNU `date` handles `-d "yesterday 3pm"` natively — python fallback rarely needed.
- **dateparser install**: `pip install dateparser` (~5MB). The skill should NOT install silently — it surfaces the missing-dep error.
- **TZ data**: macOS ships zoneinfo at `/var/db/timezone/zoneinfo`. Custom IANA zones (`America/Argentina/Buenos_Aires`) work everywhere.
