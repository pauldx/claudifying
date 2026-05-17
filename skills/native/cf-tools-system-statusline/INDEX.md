# Claude Statusline Skill (/tools-claude-statusline)

Global skill for managing Claude Code statusline with ccstatusline widget framework.

## Files in This Skill

| File | Purpose |
|------|---------|
| **README.md** | Overview, architecture, widget types, config schema |
| **SETUP_GUIDE.md** | Step-by-step installation, configuration, customization |
| **QUICK_REFERENCE.md** | Commands, config snippets, troubleshooting cheat sheet |
| **INDEX.md** | This file — entry point |

## What Is This Skill?

This skill documents and helps you set up **ccstatusline**, a dynamic statusline plugin for Claude Code.

**What it does:**
- Displays real-time widgets (model, context tokens, git branch, changes)
- Configurable via JSON (colors, layout, widget selection)
- Supports 3 status lines in Claude Code UI
- Auto-updates based on session state

**Source:** https://github.com/sirmalloc/ccstatusline.git

## Start Here

### First Time Setup
→ **SETUP_GUIDE.md** — Step 1-5 (fetch, install, load globally)

### Quick Reference
→ **QUICK_REFERENCE.md** — Commands, config snippets, troubleshooting

### Deep Dive
→ **README.md** — Architecture, widget types, advanced config

## TL;DR

```bash
# Install globally
npx -y ccstatusline@latest

# Update ~/.claude/settings.json
echo '{
  "statusLine": {
    "type": "command",
    "command": "npx -y ccstatusline@latest",
    "padding": 0,
    "refreshInterval": 10
  }
}' >> ~/.claude/settings.json

# Restart Claude Code → statusline appears automatically
```

Changes to `~/.claude/settings.json` are picked up on next Claude Code session start.

## Common Tasks

### "I want to see model + context tokens + git branch"
See **SETUP_GUIDE.md § Step 4** — configure default widgets

### "I have a caveman badge and want to keep it + add widgets"
See **SETUP_GUIDE.md § Step 5** — create wrapper script combining both

### "Colors aren't showing correctly"
See **QUICK_REFERENCE.md § Troubleshooting** → increase `colorLevel`

### "I want custom colors/separators"
See **README.md § Configuration** and **SETUP_GUIDE.md § Step 7**

### "Settings not loading"
See **QUICK_REFERENCE.md § Troubleshooting** — verify JSON syntax with `jq`

## Global Scope Integration

Claude Code loads settings on **every session start**:

```
Claude Code startup
    ↓
Read ~/.claude/settings.json
    ↓
Extract statusLine.command
    ↓
On first prompt: execute command with StatusJSON via stdin
    ↓
Display output in status bar (refreshes every 10ms)
```

**To update:** edit `~/.claude/settings.json`, restart Claude Code

## Architecture

```
ccstatusline (npm package or local binary)
    ↓
Reads: StatusJSON from stdin (Claude Code pipes it)
    ↓
Reads: ~/.config/ccstatusline/settings.json (if exists)
    ↓
Renders: Widget output (context, model, git, etc.)
    ↓
Writes: ANSI-formatted status to stdout
    ↓
Claude Code displays in status bar
```

See **README.md § Architecture** for widget types.

## Files Involved

### Yours (after setup)

```
~/.claude/settings.json
  ↓ contains statusLine.command
  ↓
~/.config/ccstatusline/settings.json (optional)
  ↓ widget config
  ↓
~/.claude/hooks/combined-statusline.sh (optional)
  ↓ if combining with custom badges
```

### ccstatusline source (GitHub)

```
src/ccstatusline.ts
  ↓ entry point
  ↓
src/types/Settings.ts (lines 30-41 = defaults)
  ↓
src/utils/renderer.ts (widget rendering)
  ↓
src/utils/claude-settings.ts (integrates with Claude Code)
```

## Key Concepts

### StatusJSON (What Claude Code Sends)

```json
{
  "model": "claude-3-5-sonnet",
  "cost": {
    "input_tokens": 1000,
    "output_tokens": 500,
    "total_duration_ms": 5000
  },
  "transcript_path": "/path/session.jsonl",
  "session_id": "abc123"
}
```

Your statusline command receives this via **stdin** and produces formatted output.

### Settings Override Cascade

1. **ccstatusline defaults** (hardcoded)
2. **~/.config/ccstatusline/settings.json** (if exists, overrides 1)
3. **CLI args** (if passed, override 1+2)

### Auto-Reload

- Settings.json changes → picked up on **next Claude Code session start**
- Config.json changes → picked up immediately (no restart needed)
- Command changes → picked up on **next session start**

## Learn By Example

### Example 1: Basic Setup
```bash
npx -y ccstatusline@latest
# Add to settings.json:
# "statusLine": {"type": "command", "command": "npx -y ccstatusline@latest"}
```

### Example 2: With Custom Config
```bash
mkdir -p ~/.config/ccstatusline
# Create settings.json with custom colors/widgets
# Restart Claude Code
```

### Example 3: Wrapper (Badge + Widgets)
```bash
# Create wrapper script that:
# 1. Reads StatusJSON from stdin
# 2. Gets caveman badge
# 3. Pipes StatusJSON to ccstatusline
# 4. Combines outputs
# Update settings.json to use wrapper
```

See **SETUP_GUIDE.md § Step 5** for full example.

## Resources

- **GitHub:** https://github.com/sirmalloc/ccstatusline
- **npm:** https://www.npmjs.com/package/ccstatusline
- **This Skill:** ~/.claude/skills/tools-claude-statusline/

## Contributing

To update this skill:
1. Test changes in ccstatusline source
2. Document in appropriate file (README/SETUP/QUICK_REF)
3. Keep examples working

## Next Steps

1. Read **SETUP_GUIDE.md § Step 1-3** (fetch + install)
2. Update `~/.claude/settings.json` (Step 3)
3. Restart Claude Code
4. Customize in `~/.config/ccstatusline/settings.json` if needed

---

**Need help?** Check **QUICK_REFERENCE.md § Troubleshooting** or review **README.md § Architecture**.
