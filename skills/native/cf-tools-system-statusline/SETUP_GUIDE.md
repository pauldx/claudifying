# Claude Statusline Setup Guide

Step-by-step guide to fetch, install, and configure ccstatusline globally.

## Step 1: Fetch Source

```bash
# Clone the repository
git clone https://github.com/sirmalloc/ccstatusline.git
cd ccstatusline

# Review structure
ls -la
# .github/          — CI/CD workflows
# src/              — TypeScript source
# dist/             — compiled output (after build)
# docs/             — documentation
# README.md         — project readme
# AGENTS.md         — AI agent integration guide
# package.json      — dependencies
```

## Step 2: Install Globally

### Option A: npm (Recommended)

```bash
# Install globally
npm install -g ccstatusline@latest

# Verify installation
which ccstatusline
ccstatusline --version  # (if supported)

# Or use without global install (always works)
npx ccstatusline@latest
```

### Option B: bunx (Faster)

```bash
# If bun installed
bunx ccstatusline@latest

# Or install globally
bun install -g ccstatusline@latest
```

### Option C: From Source

```bash
git clone https://github.com/sirmalloc/ccstatusline.git
cd ccstatusline
npm install
npm run build

# Run from local build
node dist/index.js
# Or symlink to global PATH
ln -s $(pwd)/dist/index.js /usr/local/bin/ccstatusline
```

## Step 3: Load into Global Scope

Edit `~/.claude/settings.json`:

```bash
# Backup first
cp ~/.claude/settings.json ~/.claude/settings.json.backup

# Edit with your editor
nano ~/.claude/settings.json
```

Add or update `statusLine` block:

```json
{
  "statusLine": {
    "type": "command",
    "command": "npx -y ccstatusline@latest",
    "padding": 0,
    "refreshInterval": 10
  }
}
```

Verify JSON is valid:

```bash
jq . ~/.claude/settings.json
```

## Step 4: Configure Widgets

Create local config (optional):

```bash
mkdir -p ~/.config/ccstatusline
```

Create `~/.config/ccstatusline/settings.json`:

```json
{
  "version": 3,
  "lines": [
    [
      { "id": "1", "type": "model", "color": "cyan" },
      { "id": "2", "type": "separator" },
      { "id": "3", "type": "context-length", "color": "brightBlack" },
      { "id": "4", "type": "separator" },
      { "id": "5", "type": "git-branch", "color": "magenta" },
      { "id": "6", "type": "separator" },
      { "id": "7", "type": "git-changes", "color": "yellow" }
    ],
    [],
    []
  ],
  "colorLevel": 2,
  "minimalistMode": false,
  "compactThreshold": 60,
  "flexMode": "full-minus-40"
}
```

## Step 5: Combine with Custom Statuslines (e.g., Caveman Badge)

If you have existing statusline (e.g., caveman badge), combine them:

```bash
# Create wrapper script
cat > ~/.claude/hooks/combined-statusline.sh << 'EOF'
#!/bin/bash
set -e

# Read StatusJSON from Claude Code stdin
STATUS_JSON=$(cat)

# Get custom badge (caveman example)
BADGE_OUTPUT=""
FLAG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-active"
if [ ! -L "$FLAG" ] && [ -f "$FLAG" ]; then
  MODE=$(head -c 64 "$FLAG" 2>/dev/null | tr -cd 'a-z0-9-')
  [ "$MODE" = "full" ] && BADGE_OUTPUT=$'\033[38;5;172m[CAVEMAN]\033[0m'
fi

# Get ccstatusline output
WIDGETS_OUTPUT=$(printf '%s' "$STATUS_JSON" | npx -y ccstatusline@latest 2>/dev/null || true)

# Combine: badge + widgets
if [ -n "$BADGE_OUTPUT" ] && [ -n "$WIDGETS_OUTPUT" ]; then
  printf '%b %s\n' "$BADGE_OUTPUT" "$WIDGETS_OUTPUT"
elif [ -n "$BADGE_OUTPUT" ]; then
  printf '%b\n' "$BADGE_OUTPUT"
else
  printf '%s\n' "$WIDGETS_OUTPUT"
fi
EOF

chmod +x ~/.claude/hooks/combined-statusline.sh
```

Update `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"/Users/$USER/.claude/hooks/combined-statusline.sh\""
  }
}
```

## Step 6: Test & Verify

### Manual Test

```bash
# Create sample StatusJSON
SAMPLE='{"model":"claude-3-5-sonnet","cost":{"input_tokens":1000,"output_tokens":500}}'

# Test your statusline command
echo "$SAMPLE" | npx -y ccstatusline@latest
# Output: should show widgets
```

### Auto-Load Test

1. Verify settings.json is valid:
   ```bash
   jq '.statusLine' ~/.claude/settings.json
   ```

2. Restart Claude Code

3. Check statusline appears (bottom right of Claude Code window)

## Step 7: Customize Colors & Widgets

Edit `~/.config/ccstatusline/settings.json`:

### Color Options

```json
{
  "colorLevel": 0,          // no color
  "colorLevel": 1,          // 16 colors
  "colorLevel": 2,          // 256 colors (default)
  "colorLevel": 3,          // 16M true color
  "overrideForegroundColor": "cyan",
  "overrideBackgroundColor": "black"
}
```

### Widget Options

```json
{
  "lines": [
    [
      { "type": "model", "color": "cyan", "bold": true },
      { "type": "separator", "char": " | " },
      { "type": "context-length", "color": "green" },
      { "type": "git-branch", "color": "magenta" },
      { "type": "git-changes", "color": "yellow" },
      { "type": "session-clock", "color": "white" }
    ]
  ]
}
```

### Powerline Mode (Fancy Separators)

```json
{
  "powerline": {
    "enabled": true,
    "separators": ["", ""],
    "theme": "monokai",
    "continueThemeAcrossLines": true
  }
}
```

## Step 8: Integration with Build Scripts

Add to `package.json`:

```json
{
  "scripts": {
    "statusline:install": "npm install -g ccstatusline@latest",
    "statusline:config": "npx ccstatusline@latest --config ~/.config/ccstatusline/settings.json"
  }
}
```

Or in Makefile:

```makefile
.PHONY: install-statusline
install-statusline:
	npm install -g ccstatusline@latest
	mkdir -p ~/.config/ccstatusline
	cp ccstatusline.settings.json ~/.config/ccstatusline/settings.json
	@echo "✓ Statusline installed and configured globally"
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Command not found | Use `npx -y ccstatusline@latest` or install globally |
| Statusline blank | Check settings.json valid: `jq . ~/.claude/settings.json` |
| Colors not showing | Increase `colorLevel` in config (try 2 or 3) |
| Old config cached | Remove `~/.config/ccstatusline/settings.json` and reload |
| Permission denied | Make wrapper script executable: `chmod +x ~/.claude/hooks/*.sh` |

## Files Reference

After install, key files are:

```
~/.claude/settings.json                           — global Claude Code settings
~/.config/ccstatusline/settings.json              — local statusline config
~/.claude/hooks/combined-statusline.sh (optional) — custom wrapper
~/.claude/skills/tools-claude-statusline/         — this skill
```

## Auto-Reload Behavior

Claude Code loads settings on **session start**:

1. User starts Claude Code session
2. Claude Code reads `~/.claude/settings.json`
3. Extracts `statusLine.command`
4. On first prompt → executes statusLine command with StatusJSON
5. Displays output in status bar
6. Updates every `refreshInterval` ms (default 10s)

**Changes to settings.json are picked up on next session start.**

## Next Steps

- Explore `~/.config/ccstatusline/settings.json` for advanced theming
- Use TUI config editor: `ccstatusline` (interactive mode)
- Check `src/types/Widget.ts` for all available widget types
- Review `AGENTS.md` in ccstatusline repo for AI integration patterns
