# Plugins

Claude Code plugins extend functionality with custom tools and integrations.

## What's a Plugin?

Plugins add new capabilities to Claude Code:
- Custom integrations (Slack, Discord, etc.)
- External API bridges
- Custom tool definitions
- Enhanced workflows

## Directory Structure

```
plugins/
├── plugin-name/
│   ├── README.md
│   ├── plugin.json
│   ├── src/
│   │   └── index.js
│   └── LICENSE (optional)
```

## How to Use

1. Copy plugin folder to `~/.claude/plugins/`
2. Configure in Claude Code settings
3. Restart Claude Code

## Creating a Plugin

See CONTRIBUTING.md for structure and guidelines.

## Available Plugins

(Coming soon — community contributions welcome!)

## Resources

- [Claude Code Plugin Docs](https://code.claude.com/docs/plugins)
- [Contributing Guide](../CONTRIBUTING.md)
