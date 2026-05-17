---
name: cf-tools-system-disk-free
description: "Parse df -h into a readable table and warn on volumes above 80% full. Trigger: /cf-tools-system-disk-free"
trigger: /cf-tools-system-disk-free
version: 1.0.0
---

# /cf-tools-system-disk-free

Show disk usage across all mounted volumes in a clean table. Highlights any
filesystem at or above 80% capacity with a warning. Optionally filters to real
disks (skips devfs, tmpfs, overlay).

## Usage

```
/cf-tools-system-disk-free                 # all volumes
/cf-tools-system-disk-free --real          # skip virtual filesystems
/cf-tools-system-disk-free --threshold 90  # warn at 90%+ instead of 80%
```

Arguments:
- `--real` (optional flag) — exclude devfs, tmpfs, overlay, none, map
- `--threshold N` (optional, default `80`) — warning percentage

## What You Must Do When Invoked

### Step 1 — Run df

```bash
df -h | tail -n +2 > /tmp/dfout.$$
```

### Step 2 — Parse and tabulate

```bash
REAL=0
THRESH=80
for i in "$@"; do
  [ "$i" = "--real" ] && REAL=1
  case "$i" in --threshold) THRESH_NEXT=1 ;; esac
done
# Crude flag-pair parsing
prev=""
for i in "$@"; do
  [ "$prev" = "--threshold" ] && THRESH="$i"
  prev="$i"
done

python3 - "$REAL" "$THRESH" /tmp/dfout.$$ <<'PY'
import sys
real_only = sys.argv[1] == "1"
thresh    = int(sys.argv[2])
virtuals  = {"devfs", "tmpfs", "overlay", "none", "map", "auto_home"}

rows = []
warns = []
with open(sys.argv[3]) as fh:
    for line in fh:
        parts = line.split(None, 8)
        if len(parts) < 6:
            continue
        # df -h on macOS: Filesystem Size Used Avail Capacity iused ifree %iused Mounted
        # df -h on Linux: Filesystem Size Used Avail Use% Mounted
        fs = parts[0]
        if real_only and any(fs.startswith(v) or fs == v for v in virtuals):
            continue
        # Find the percentage column (ends with %)
        pct_col = None
        for j, p in enumerate(parts):
            if p.endswith("%") and p[:-1].isdigit():
                pct_col = j
                pct_val = int(p[:-1])
                break
        if pct_col is None:
            continue
        size  = parts[1]
        used  = parts[2]
        avail = parts[3]
        mount = parts[-1].rstrip("\n")
        row   = (fs[:30], size, used, avail, f"{pct_val}%", mount)
        rows.append(row)
        if pct_val >= thresh:
            warns.append((mount, pct_val))

# Render table
hdr = ("Filesystem", "Size", "Used", "Avail", "Use%", "Mount")
widths = [max(len(str(r[i])) for r in rows + [hdr]) for i in range(6)]
def fmt(r):
    return "  ".join(str(r[i]).ljust(widths[i]) for i in range(6))
print(fmt(hdr))
print("  ".join("-" * w for w in widths))
for r in rows:
    print(fmt(r))

print()
if warns:
    print(f"WARNING: {len(warns)} volume(s) at or above {thresh}%:")
    for m, p in warns:
        print(f"  {m}  {p}%")
else:
    print(f"OK: all volumes below {thresh}%.")
PY
rm -f /tmp/dfout.$$
```

## Output Contract

```
## Disk usage

Filesystem      Size  Used  Avail  Use%  Mount
--------------  ----  ----  -----  ----  ----------
/dev/disk1s5s1  466G  14G   36G    28%   /
...

OK: all volumes below 80%.

— or —

WARNING: 1 volume(s) at or above 80%:
  /System/Volumes/Data  87%
```

## Gotchas

- **macOS APFS shares space across containers** — the `Avail` column you see
  for `/` already accounts for siblings. Don't sum used columns.
- **Snapshot space invisible** — APFS local snapshots aren't counted in `Used`.
  Run `tmutil listlocalsnapshots /` to investigate `disk full` despite low df.
- **`Capacity` (9th col) vs `Use%` (5th col)** — macOS df uses different column
  layout than Linux. The parser scans for whichever column ends in `%` and
  contains digits.
- **Virtual mounts (`/dev`, `/proc`, `/sys`)** — pass `--real` to hide them.
  These always report 100% on Linux because they have no backing storage.
- **Snap mounts on Ubuntu** — `/snap/*` shows up as squashfs, always 100%.
  `--real` filters these out.
- **Threshold compares the integer percentage** — `df` rounds, so a volume at
  79.6% may show as `80%` and trip the warning. That's intentional.

## Cross-Platform Notes

- **macOS / BSD**: 9-column `df -h` output. Parser handles it via regex.
- **Linux**: 6-column `df -h` output. Same parser works.
- **Windows**: not supported by this skill — use PowerShell `Get-Volume`.
