---
name: cf-tools-system-brew-orphan
description: "List Homebrew formulae installed on request that no other formula depends on (orphan candidates for cleanup). Trigger: /cf-tools-system-brew-orphan"
trigger: /cf-tools-system-brew-orphan
version: 1.0.0
---

# /cf-tools-system-brew-orphan

Show every formula you installed explicitly (via `brew install`) that no other
installed formula depends on. These are the safest deletion candidates if
you're cleaning up disk space.

Uses `brew leaves --installed-on-request`. By default reports each formula with
its install size; pass `--names-only` for a plain list.

## Usage

```
/cf-tools-system-brew-orphan                # full report with sizes
/cf-tools-system-brew-orphan --names-only   # plain newline-separated names
/cf-tools-system-brew-orphan --casks        # include casks too (slower)
```

Arguments:
- `--names-only` (optional flag) — output bare formula names
- `--casks` (optional flag) — also list installed casks (no dependency check)

## What You Must Do When Invoked

### Step 1 — Verify brew installed

```bash
if ! command -v brew >/dev/null 2>&1; then
  echo "ERROR: Homebrew not installed. Visit https://brew.sh"
  exit 1
fi
```

### Step 2 — Get the orphan list

```bash
ORPHANS=$(brew leaves --installed-on-request 2>/dev/null)
COUNT=$(echo "$ORPHANS" | grep -c .)
```

`brew leaves` already filters to formulae that are *not* depended on by any
other installed formula. Adding `--installed-on-request` excludes ones that
were originally pulled in as a dependency and only later became orphans.

### Step 3 — Output

```bash
NAMES_ONLY=0; CASKS=0
for a in "$@"; do
  [ "$a" = "--names-only" ] && NAMES_ONLY=1
  [ "$a" = "--casks" ]      && CASKS=1
done

if [ "$NAMES_ONLY" -eq 1 ]; then
  echo "$ORPHANS"
else
  echo "## Brew orphan formulae ($COUNT installed-on-request, no dependents)"
  echo
  printf "%-40s  %-10s  %s\n" "Formula" "Size"      "Description"
  printf "%-40s  %-10s  %s\n" "$(printf '%.0s-' {1..40})" "----------" "-----------"
  for f in $ORPHANS; do
    INFO=$(brew info --json=v2 "$f" 2>/dev/null)
    SIZE=$(echo "$INFO" | python3 -c '
import json,sys
try:
    d = json.load(sys.stdin)["formulae"][0]
    inst = d.get("installed",[{}])[0]
    p = inst.get("installed_as_dependency"), inst.get("installed_on_request")
    # rough size via keg path is brittle; use brew --prefix
    import os, subprocess
    pre = subprocess.run(["brew","--prefix",d["name"]],capture_output=True,text=True).stdout.strip()
    if pre and os.path.isdir(pre):
        s = subprocess.run(["du","-sh",pre],capture_output=True,text=True).stdout.split()[0]
        print(s)
    else:
        print("?")
except Exception:
    print("?")
')
    DESC=$(echo "$INFO" | python3 -c 'import json,sys;d=json.load(sys.stdin)["formulae"][0];print(d.get("desc","")[:60])' 2>/dev/null)
    printf "%-40s  %-10s  %s\n" "$f" "$SIZE" "$DESC"
  done
fi

if [ "$CASKS" -eq 1 ]; then
  echo
  echo "## Installed casks (no automated orphan detection)"
  brew list --cask 2>/dev/null
fi
```

### Step 4 — Suggest action

```bash
echo
echo "To remove a formula: brew uninstall <name>"
echo "To remove with dependencies that became orphans: brew autoremove"
```

## Output Contract

```
## Brew orphan formulae (<N> installed-on-request, no dependents)

Formula                                  Size        Description
---------------------------------------  ----------  -----------
awscli                                   123M        Official AWS CLI
ffmpeg                                   89M         Multimedia framework
jq                                       2.1M        Command-line JSON processor
...

To remove a formula: brew uninstall <name>
To remove with dependencies that became orphans: brew autoremove
```

With `--names-only`, output is just newline-separated names suitable for
piping to `xargs brew uninstall`.

## Gotchas

- **`brew leaves` vs `brew leaves --installed-on-request`** — the bare form
  also lists formulae that were originally pulled in as a dependency. Using
  `--installed-on-request` is more honest about *what you explicitly asked for*
  that is now an orphan candidate.
- **Casks aren't in the dependency graph** — Homebrew tracks formulae deps but
  not cask-on-formula deps. `--casks` only lists them; doesn't classify as
  orphans.
- **`brew autoremove`** — removes formulae installed as deps that no installed
  formula needs anymore. Different from this skill (which surfaces what *you*
  installed).
- **Sizing via `du -sh $(brew --prefix <f>)`** — counts the keg but not
  shared resources. Numbers are approximate; treat them as relative not
  authoritative.
- **`brew info` is slow over many formulae** — for a system with 100+ leaves,
  expect 5-10 seconds total. Use `--names-only` to skip the metadata pass.
- **Python `du` subprocess fallback** — on systems where `brew --prefix
  <formula>` doesn't resolve (older brew), size shows `?`.

## Cross-Platform Notes

- **macOS / Linuxbrew**: identical behavior. Linuxbrew prefix differs
  (`/home/linuxbrew/.linuxbrew` vs `/usr/local` or `/opt/homebrew`) but
  `brew --prefix` resolves correctly.
- **Apple Silicon vs Intel macOS**: `/opt/homebrew` vs `/usr/local` — handled
  automatically.
- **Windows**: not supported — no Homebrew on Windows; use `winget` equivalent
  patterns instead.
