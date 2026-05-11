# Claude Statusline Skill

Dynamic statusline for Claude Code with widget-based architecture, token tracking, git integration, and compression telemetry.

**Source:** [sirmalloc/ccstatusline](https://github.com/sirmalloc/ccstatusline.git)

## Quick Start

### Installation

```bash
# Via npm (recommended for global install)
npx -y ccstatusline@latest

# Via bunx (faster if bun installed)
bunx -y ccstatusline@latest

# Or clone and build locally
git clone https://github.com/sirmalloc/ccstatusline.git
cd ccstatusline
npm install && npm run build
```

### Setup in Claude Code

Add to `~/.claude/settings.json`:

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

### With Custom Wrapper (e.g., caveman badge + statusline)

```bash
# Create wrapper script
cat > ~/.claude/hooks/combined-statusline.sh << 'EOF'
#!/bin/bash
STATUS_JSON=$(cat)
# Your custom logic here (caveman badge, etc.)
printf '%s' "$STATUS_JSON" | npx -y ccstatusline@latest
EOF

chmod +x ~/.claude/hooks/combined-statusline.sh
```

Then in `settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"/Users/$USER/.claude/hooks/combined-statusline.sh\""
  }
}
```

## Architecture

### Default Widgets (Line 1)

```
[model] [separator] [context-length] [separator] [git-branch] [separator] [git-changes]
```

Defined in `src/types/Settings.ts:30-41`:
- `model` — current Claude model
- `context-length` — used/total context tokens
- `git-branch` — current branch
- `git-changes` — unstaged changes indicator

### Configuration

Local config: `~/.config/ccstatusline/settings.json`

Example:

```json
{
  "version": 3,
  "lines": [
    [
      { "id": "1", "type": "model", "color": "cyan" },
      { "id": "2", "type": "separator" },
      { "id": "3", "type": "context-length", "color": "brightBlack" }
    ]
  ],
  "colorLevel": 2,
  "minimalistMode": false,
  "powerline": {
    "enabled": false,
    "separators": [""]
  }
}
```

### Available Widget Types

- `model` — Claude model name
- `context-length` — context usage (tokens/max)
- `input-speed` — tokens/sec (input)
- `output-speed` — tokens/sec (output)
- `total-speed` — total tokens/sec
- `session-clock` — elapsed time
- `git-branch` — current git branch
- `git-changes` — file status
- `compaction-counter` — context compressions
- `separator` — visual separator

## Global Scope Integration

### Via Settings (Recommended)

Claude Code reads `~/.claude/settings.json` on every session start. Changes are automatic.

```bash
# Update and verify
jq '.statusLine.command' ~/.claude/settings.json
# Claude picks up on next session start
```

### Programmatic Setup

```typescript
// src/utils/claude-settings.ts
export async function installStatusLine(useBunx = false): Promise<void> {
  const settings = await loadClaudeSettings();
  settings.statusLine = {
    type: 'command',
    command: useBunx
      ? 'bunx -y ccstatusline@latest'
      : 'npx -y ccstatusline@latest',
    padding: 0
  };
  await saveClaudeSettings(settings);
}
```

## Advanced: StatusJSON Schema

Claude Code pipes this JSON to statusLine command via stdin:

```typescript
interface StatusJSON {
  model?: string;
  cost?: {
    input_tokens?: number;
    output_tokens?: number;
    cache_creation_input_tokens?: number;
    cache_read_input_tokens?: number;
    total_duration_ms?: number;
  };
  transcript_path?: string;
  session_id?: string;
}
```

Your statusLine command reads this from stdin and produces formatted output:

```bash
#!/bin/bash
STATUS_JSON=$(cat)  # From Claude Code
# Process $STATUS_JSON, output ANSI-formatted status
```

## Troubleshooting

### Statusline blank

- Check `settings.json` is valid JSON: `jq . ~/.claude/settings.json`
- Verify command path exists: `which ccstatusline`
- Test directly: `echo '{}' | npx -y ccstatusline@latest`

### Command not found

Install globally:

```bash
npm install -g ccstatusline@latest
# Or use npx prefix in settings.json
```

### Custom config not loading

Ensure `~/.config/ccstatusline/settings.json` is valid:

```bash
jq . ~/.config/ccstatusline/settings.json
```

Local config overrides global. Check precedence in `src/utils/config.ts`.

## Files

| File | Purpose |
|------|---------|
| `src/ccstatusline.ts` | Entry point, renders multiple lines |
| `src/types/Settings.ts` | Schema + defaults |
| `src/utils/claude-settings.ts` | Load/save Claude settings.json |
| `src/tui/claude-status.ts` | TUI mode for config editor |
| `src/utils/renderer.ts` | Widget rendering + layout |

## Sync with Project Code

Keep ccstatusline in sync with local code statuslines:

1. **Global** (`~/.claude/settings.json`) — applies to all projects
2. **Project local** (`~/.config/ccstatusline/settings.json`) — per-project override
3. **Wrapper script** (`~/.claude/hooks/*.sh`) — combine statuslines (e.g., badge + widgets)

Changes to `settings.json` auto-reload on next Claude Code session.

## Resources

- **GitHub:** https://github.com/sirmalloc/ccstatusline
- **npm:** https://www.npmjs.com/package/ccstatusline
- **Source:** Built with TypeScript, Zod validation, Node.js
