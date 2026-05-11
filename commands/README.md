# Commands

Custom CLI commands and workflows for Claude Code.

## What's a Command?

Commands are:
- Custom CLI tools
- Workflow scripts
- Task runners
- Integration binaries

## Directory Structure

```
commands/
├── command-name/
│   ├── README.md
│   ├── command.sh (or .js, .py)
│   ├── config.json
│   └── LICENSE (optional)
```

## Command Format

### Bash Command
```bash
#!/bin/bash
# command-name

set -e

# Your command implementation
```

### Add to Keybindings

```json
{
  "keybindings": [
    {
      "key": "ctrl+shift+x",
      "command": "commands/command-name/command.sh"
    }
  ]
}
```

## How to Use

### Via CLI
```bash
./commands/command-name/command.sh [args]
```

### Via Keybinding
```json
{
  "key": "ctrl+shift+k",
  "command": "commands/command-name"
}
```

## Creating a Command

See CONTRIBUTING.md for structure and guidelines.

## Available Commands

(Coming soon — community contributions welcome!)

## Examples

- `deploy` — deployment workflow
- `format` — code formatter
- `test` — test runner
- `docs` — documentation generator
- `lint` — linter integration

## Resources

- [Claude Code Keybindings](https://code.claude.com/docs/keybindings)
- [Contributing Guide](../CONTRIBUTING.md)
