---
name: cf-tools-system-top-cpu
description: "List top N processes by CPU usage with PID, percent, and command. Trigger: /cf-tools-system-top-cpu"
trigger: /cf-tools-system-top-cpu
version: 1.0.0
---

# /cf-tools-system-top-cpu

Show the top-N CPU-consuming processes right now. Lightweight — uses `ps`
rather than `top`, so no interactive screen takeover. Default N = 10.

## Usage

```
/cf-tools-system-top-cpu                # top 10
/cf-tools-system-top-cpu 5              # top 5
/cf-tools-system-top-cpu 20 --full      # top 20, full command line (no truncation)
```

Arguments:
1. `n` (optional, default `10`) — number of rows to show
2. `--full` (optional flag) — show full command + args (not just basename)

## What You Must Do When Invoked

### Step 1 — Parse args

```bash
N="${1:-10}"
case "$N" in --*) N=10 ;; esac
[ "$N" -gt 0 ] 2>/dev/null || N=10

FULL=0
for a in "$@"; do [ "$a" = "--full" ] && FULL=1; done
```

### Step 2 — Run ps

`ps -axo pid,pcpu,comm` works on both macOS and Linux. `comm` is basename;
`command` (or `args`) is the full argv.

```bash
if [ "$FULL" -eq 1 ]; then
  ps -axo pid,pcpu,command | sort -k2 -nr | head -n "$((N + 1))"
else
  ps -axo pid,pcpu,comm    | sort -k2 -nr | head -n "$((N + 1))"
fi
```

The `+1` accounts for the header row that `ps` emits, which sorts to where its
literal text falls — wrap with awk for cleaner output.

### Step 3 — Format as a markdown table

```bash
ps -axo pid,pcpu,${FULL:+command}${FULL:+}${FULL:-comm} 2>/dev/null \
  | awk 'NR==1 {next} {print}' \
  | sort -k2 -nr \
  | head -n "$N" \
  | awk -v full=$FULL '
    BEGIN { print "| PID    | %CPU  | Command |"; print "|--------|-------|---------|" }
    {
      pid=$1; cpu=$2; $1=""; $2="";
      cmd=substr($0, 3);
      if (!full && length(cmd) > 60) cmd = substr(cmd, 1, 57) "...";
      printf "| %-6s | %-5s | %s |\n", pid, cpu, cmd
    }'
```

### Step 4 — Summary

```bash
TOTAL=$(ps -axo pcpu | awk 'NR>1 {s+=$1} END {printf "%.1f", s}')
CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 1)
echo
echo "Total CPU across all processes: ${TOTAL}% (system has ${CORES} cores → max ${CORES}00%)"
```

## Output Contract

```
## Top <N> processes by CPU

| PID    | %CPU  | Command                          |
|--------|-------|----------------------------------|
| 1234   | 87.3  | node /usr/local/bin/some-server  |
| 5678   | 12.4  | Google Chrome Helper (Renderer)  |
...

Total CPU across all processes: 142.7% (system has 10 cores → max 1000%)
```

## Gotchas

- **macOS `%CPU` can exceed 100%** — that's per-core normalized. A multithreaded
  process on a 10-core machine can show 800%. Compare against the total/cores
  ratio in the footer.
- **Linux `%CPU` is also multi-core** — same caveat. Use `top -1` interactively
  for per-core breakdown.
- **`ps` is a snapshot, not an average** — for sustained-load investigation use
  `top -l 5 -s 1` (macOS) or `top -bn 5 -d 1` (Linux).
- **Kernel threads on Linux** — appear with bracketed names like `[kworker/0:1]`.
  They can legitimately consume CPU.
- **Truncated `comm` hides which python/node script is running** — pass
  `--full` to see argv. Some processes (Chromium) have very long argv strings.
- **Zombie processes show `<defunct>`** — they consume no CPU; they just haven't
  been reaped by their parent.

## Cross-Platform Notes

- **macOS / Linux / BSD**: `ps -axo pid,pcpu,comm` is portable.
- **Windows**: not supported — use `Get-Process | Sort-Object CPU -Descending`
  in PowerShell.
