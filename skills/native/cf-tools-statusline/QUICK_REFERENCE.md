# Claude Statusline — Quick Reference

## One-Liner Install

```bash
# Install globally (no npm needed)
npx -y ccstatusline@latest

# Add to ~/.claude/settings.json
jq '.statusLine |= {"type":"command","command":"npx -y ccstatusline@latest","padding":0,"refreshInterval":10}' ~/.claude/settings.json > /tmp/settings.json && mv /tmp/settings.json ~/.claude/settings.json
```

## Key Commands

```bash
# Test directly
echo '{"model":"haiku"}' | npx -y ccstatusline@latest

# Configure (TUI editor)
ccstatusline

# View current settings
jq '.statusLine' ~/.claude/settings.json

# Verify settings.json
jq . ~/.claude/settings.json
```

## Default Widgets

| Widget | Type | Example Output |
|--------|------|----------------|
| model | `"model"` | `claude-3-5-sonnet` |
| context-length | `"context-length"` | `Ctx: 45,213/100,000` |
| input-speed | `"input-speed"` | `In: 1.2K tok/s` |
| output-speed | `"output-speed"` | `Out: 3.4K tok/s` |
| git-branch | `"git-branch"` | `⎇ main` |
| git-changes | `"git-changes"` | `?` (unstaged) |
| separator | `"separator"` | ` \| ` |

## Settings Locations

| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Global Claude Code settings (auto-loads on session start) |
| `~/.config/ccstatusline/settings.json` | Local statusline config (overrides defaults) |
| `~/.claude/hooks/*.sh` | Custom wrapper scripts |

## Config Example

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

## Custom Wrapper (Caveman + Widgets)

```bash
cat > ~/.claude/hooks/combined-statusline.sh << 'EOF'
#!/bin/bash
STATUS_JSON=$(cat)
BADGE=$([ -f ~/.claude/.caveman-active ] && echo $'\033[38;5;172m[CAVEMAN]\033[0m' || echo "")
WIDGETS=$(printf '%s' "$STATUS_JSON" | npx -y ccstatusline@latest 2>/dev/null || true)
[ -n "$BADGE" ] && [ -n "$WIDGETS" ] && printf '%b %s\n' "$BADGE" "$WIDGETS" || printf '%s\n' "${BADGE}${WIDGETS}"
EOF
chmod +x ~/.claude/hooks/combined-statusline.sh
```

Then update `settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"/Users/$USER/.claude/hooks/combined-statusline.sh\""
  }
}
```

## Colors

```json
{
  "colorLevel": 0,  // no color
  "colorLevel": 1,  // 16 colors
  "colorLevel": 2,  // 256 colors
  "colorLevel": 3,  // 16M true color (default)
  "overrideForegroundColor": "cyan"
}
```

## Auto-Load Behavior

1. Claude Code starts → reads `~/.claude/settings.json`
2. First prompt → executes `statusLine.command` with StatusJSON via stdin
3. Updates every `refreshInterval` ms
4. **Changes to settings.json picked up on next session start**

## StatusJSON Format (What Claude Code Sends)

```typescript
{
  "model": "claude-3-5-sonnet",
  "cost": {
    "input_tokens": 1000,
    "output_tokens": 500,
    "cache_creation_input_tokens": 0,
    "cache_read_input_tokens": 0,
    "total_duration_ms": 5000
  },
  "transcript_path": "/path/to/session.jsonl",
  "session_id": "uuid-here"
}
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Blank statusline | `jq . ~/.claude/settings.json` check syntax |
| Command not found | Use `npx -y ccstatusline@latest` prefix |
| Old config cached | Delete `~/.config/ccstatusline/settings.json` |
| Colors not showing | Increase `colorLevel` (try 2) |
| Script permission denied | `chmod +x ~/.claude/hooks/*.sh` |

## Source Code

**Repository:** https://github.com/sirmalloc/ccstatusline.git

Key files:
- `src/ccstatusline.ts` — entry point
- `src/types/Settings.ts` — config schema (defaults on line 30-41)
- `src/utils/claude-settings.ts` — Claude integration
- `src/utils/renderer.ts` — widget rendering

## Resources

- **npm:** `npx -y ccstatusline@latest`
- **GitHub:** https://github.com/sirmalloc/ccstatusline
- **Docs:** See SETUP_GUIDE.md in this skill

## Next Steps

1. Install: `npx -y ccstatusline@latest`
2. Update `~/.claude/settings.json`
3. Restart Claude Code
4. Customize in `~/.config/ccstatusline/settings.json`
