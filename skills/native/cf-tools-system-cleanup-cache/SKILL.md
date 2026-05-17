---
name: cf-tools-system-cleanup-cache
description: When the user asks to clean caches, free disk space, clear npm/brew/yarn/pip caches, or reclaim storage — activate this system cleanup skill
---

# Cache Cleanup Utility

Multi-level cache cleanup that reclaims disk space by clearing package manager caches, build artifacts, and development tool caches. Always shows what will be removed before executing.

## Activation

- User says "clean caches", "free disk space", "clear npm cache", "reclaim storage"
- User asks about large cache directories eating disk space
- User wants to clean up after a long development session

## Process

### 0. Detect OS

Before running any cleanup, detect the platform — cache paths differ between macOS and Linux:

```bash
OS=$(uname -s)  # Darwin = macOS, Linux = Linux
```

Paths below are macOS examples (`~/Library/Caches/`). On Linux, substitute `~/.cache/` equivalents.

## Levels

### Conservative (default)

Safe caches that regenerate automatically on next use:

```bash
npm cache clean --force
brew cleanup --prune=all
rm -rf ~/Library/Caches/Yarn
```

### Aggressive (--aggressive)

Everything above, plus browser and dev tool caches:

- **Browser caches**: Chrome, Firefox, Arc, Opera (under `~/Library/Caches/`)
- **Dev tool caches**: JetBrains IDEs (`~/Library/Caches/JetBrains*`), pnpm (`~/.local/share/pnpm/store`), puppeteer (`~/.cache/puppeteer`)
- **Build caches**: Gradle (`~/.gradle/caches`), Maven (`~/.m2/repository`)

### Maximum (--maximum)

Everything above, plus heavy-hitter caches:

```bash
docker system prune -af --volumes
pip cache purge
conda clean --all -y
```

- **ML caches**: `~/.cache/huggingface`, `~/.cache/torch`
- **iOS/macOS dev**: `~/Library/Developer/Xcode/DerivedData`
- **Misc**: `~/.cache/go-build`, `~/.rustup/tmp`

## Process

### 1. Survey Disk State

Report current usage before any cleanup:

```bash
df -h / | tail -1
```

### 2. Scan Applicable Caches

For each cache directory that exists, show its size:

```bash
du -sh ~/.npm ~/.cache/yarn ~/Library/Caches/Homebrew 2>/dev/null
```

Only list caches that actually exist on the system — skip missing directories silently.

### 3. Present Cleanup Plan

Show a table of what will be cleaned:

| Cache | Size | Level |
|-------|------|-------|
| npm cache | 1.2G | Conservative |
| Yarn cache | 340M | Conservative |
| Chrome cache | 890M | Aggressive |
| Docker images | 12G | Maximum |

### 4. Execute with Confirmation

- **Conservative**: Execute immediately (safe, regenerates on demand)
- **Aggressive**: Ask for confirmation before proceeding — browser caches may log out sessions
- **Maximum**: Require explicit confirmation — Docker prune removes all unused images and volumes

### 5. Report Results

```bash
df -h / | tail -1
```

Show before/after disk usage and total space reclaimed.

## Output

- Disk usage summary (before and after)
- Per-cache size breakdown
- Total space reclaimed
- Any caches that were skipped and why

## Gotchas

- **Homebrew cleanup** can take several minutes on systems with many formulae — warn the user
- **Docker prune -af** removes ALL unused images, not just dangling ones — this can force re-pulls of base images that take significant time and bandwidth
- **Browser caches** will log out of some sites and slow down first page loads after cleanup
- **npm cache clean --force** is required — npm refuses without the flag but the cache is safe to clear
- **Conda environments** are NOT touched by `conda clean` — only package caches are removed
- **Xcode DerivedData** can be massive (50G+) but rebuilds are slow — only clean if user confirms
- Always use `2>/dev/null` when scanning cache paths since many may not exist on a given system
- Never delete `~/.npm` itself — only run `npm cache clean` which handles the internals safely
- Paths vary across macOS and Linux — use `$HOME` not hardcoded `/Users/` paths
