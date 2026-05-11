# Hooks

Hooks are scripts that execute in response to Claude Code events.

## What's a Hook?

Hooks automate actions on events:
- Pre/post commit
- Startup/shutdown
- Before/after commands
- Custom workflows

## Hook Types

- `startup` — runs when Claude Code starts
- `pre_commit` — before commit
- `post_commit` — after commit
- `command` — custom command hook
- `error` — on error events

## Directory Structure

```
hooks/
├── hook-name/
│   ├── README.md
│   ├── hook.sh (or .js)
│   ├── config.json
│   └── LICENSE (optional)
```

## How to Use

1. Copy hook script to `~/.claude/hooks/`
2. Reference in `.claude/settings.json`:
   ```json
   {
     "hooks": {
       "startup": "path/to/hook.sh"
     }
   }
   ```
3. Restart Claude Code

## Creating a Hook

See CONTRIBUTING.md for structure and guidelines.

## Available Hooks

(Coming soon — community contributions welcome!)

## Resources

- [Claude Code Hooks Docs](https://code.claude.com/docs/hooks)
- [Contributing Guide](../CONTRIBUTING.md)
