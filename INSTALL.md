# Claudifying Installation Guide

Install claudifying extensions globally so they're available in all your projects.

## Quick Start

### 1. Clone Claudifying
```bash
git clone https://github.com/pauldx/claudifying.git
cd claudifying
```

### 2. Install Extensions
```bash
./install.sh
```

### 3. Start Using
```bash
# In any Claude Code project:
/code-git-create-repo my-project
/code-optmz-graph
```

## Installation Methods

### Method 1: Direct Install (Recommended)
```bash
./install.sh
```

Symlinks all extensions into `~/.claude/`:
- `skills/` → `~/.claude/skills/`
- `plugins/` → `~/.claude/plugins/`
- `hooks/` → `~/.claude/hooks/`
- `prompts/` → `~/.claude/prompts/`

Extensions work in ALL projects immediately.

### Method 2: Dry Run (Preview)
```bash
./install.sh --dry-run
```

Shows what WOULD be installed without making changes.

### Method 3: Force Replace
```bash
./install.sh --force
```

Replaces existing symlinks/files (backs up originals).

## Installation Options

| Option | Effect |
|--------|--------|
| `(none)` | Install with checks, skip conflicts |
| `--dry-run` | Preview changes, don't install |
| `--force` | Replace existing, back up originals |
| `--uninstall` | Remove all claudifying symlinks |
| `--help` | Show help message |

## How It Works

### Symlink Architecture
```
Claudifying (source)
├── skills/
│   ├── code-git-create-repo/
│   ├── code-optmz-graph/
│   └── ...
└── plugins/
    └── ...
        ↓ symlinks ↓
~/.claude/ (global)
├── skills/
│   ├── code-git-create-repo → /path/to/claudifying/skills/code-git-create-repo
│   ├── code-optmz-graph → /path/to/claudifying/skills/code-optmz-graph
│   └── ...
└── plugins/
    └── ...
```

**Benefits:**
- ✅ Single source of truth
- ✅ No duplication
- ✅ Updates instant (no reinstall)
- ✅ Version controlled
- ✅ Easy to contribute back

### What Gets Installed

#### Skills (`~/.claude/skills/`)
Invocable tools — call with `/skill-name`

```bash
/code-git-create-repo my-project
/code-optmz-caveman
/code-optmz-graph
/tools-statusline
```

#### Plugins (`~/.claude/plugins/`)
System extensions — auto-loaded by Claude Code

#### Hooks (`~/.claude/hooks/`)
Event-driven automation — configure in `settings.json`

#### Prompts (`~/.claude/prompts/`)
Reusable templates — reference in CLAUDE.md

## Uninstalling

### Remove All
```bash
./uninstall.sh
```

Or:
```bash
./install.sh --uninstall
```

Removes all symlinks pointing to claudifying from `~/.claude/`.

### Remove Specific Extension
```bash
rm ~/.claude/skills/code-optmz-graph
```

## Troubleshooting

### "Permission denied" when running install.sh
Make scripts executable:
```bash
chmod +x install.sh uninstall.sh
```

### "~/.claude/ does not exist"
Install Claude Code first, then run installer.

### Symlink already exists (conflict)
Use `--force` to replace:
```bash
./install.sh --force
```

Original backed up to: `~/.claude/backups/pre-claudifying-install-[timestamp]/`

### Extensions not showing in Claude Code
1. Verify symlinks: `ls -la ~/.claude/skills/`
2. Restart Claude Code
3. Check symlink target: `readlink ~/.claude/skills/skill-name`
4. Verify file permissions: `chmod -R 755 ~/.claude/skills/`

### "Too many levels of symbolic links"
Broken symlink chain. Check:
```bash
readlink ~/.claude/skills/skill-name
# Should point to absolute path in claudifying repo
```

Fix:
```bash
rm ~/.claude/skills/skill-name
./install.sh
```

## Updating Claudifying

### Get Latest
```bash
cd /path/to/claudifying
git pull origin main
```

**No reinstall needed!** Symlinks automatically point to latest changes.

### Check for Updates
```bash
cd /path/to/claudifying
git status
git log --oneline -5  # Recent changes
```

## Advanced Usage

### Custom Installation Path
Edit paths in `install.sh` or create wrapper:

```bash
REPO_DIR="/custom/path/to/claudifying" ./install.sh
```

### Selective Install
Modify `install.sh` to comment out unwanted sections:

```bash
# Skip plugins
# plugin_count=0
# for plugin_dir in "$REPO_DIR/plugins"/*/; do
#   ...
# done
```

### Multiple Repositories
Install different repos to same `~/.claude/`:

```bash
# Install claudifying (core tools)
cd ~/repos/claudifying && ./install.sh

# Install team-specific tools (optional)
cd ~/repos/team-tools && ./install.sh

# Both coexist in ~/.claude/
ls ~/.claude/skills/
```

Extensions accessible from all projects.

## Distribution

### Share With Team
1. User clones repo
2. User runs `./install.sh`
3. Extensions available globally

### As a Package
Use install scripts in:
- Onboarding docs
- CI/CD pipelines
- Docker images
- Setup scripts

## Backup & Recovery

### Automatic Backups
Before `--force` or `--uninstall`:
- Location: `~/.claude/backups/pre-claudifying-install-[timestamp]/`
- Contents: Original files/symlinks
- Auto-deleted: No, kept for safety

### Manual Restore
```bash
# If something went wrong:
rm ~/.claude/skills/bad-symlink
cp ~/.claude/backups/pre-claudifying-install-YYYYMMDD-HHMMSS/bad-symlink ~/.claude/skills/
```

## Support

- **Issues**: [GitHub Issues](https://github.com/pauldx/claudifying/issues)
- **Contributing**: See [CONTRIBUTING.md](./CONTRIBUTING.md)
- **Docs**: Check [README.md](./README.md)

---

**Version:** 1.0
**Last Updated:** 2026-05-03
**Repo:** https://github.com/pauldx/claudifying
