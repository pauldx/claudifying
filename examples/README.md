# Examples

Sample implementations and integration guides for all Claudifying extensions.

## Contents

- **Integration Guides** — step-by-step setup instructions
- **Working Examples** — complete, runnable implementations
- **Templates** — copy-paste starting points
- **Best Practices** — patterns and conventions

## Directory Structure

```
examples/
├── plugin-integration/
│   ├── README.md
│   └── sample-plugin/
├── hook-setup/
│   ├── README.md
│   └── sample-hook/
├── skill-creation/
│   ├── README.md
│   └── sample-skill/
├── prompt-templates/
│   ├── README.md
│   └── sample-prompt/
└── command-scripts/
    ├── README.md
    └── sample-command/
```

## Quick Start

### 1. Pick an Extension Type
- Plugins
- Hooks
- Skills
- Prompts
- Commands

### 2. Find Example
```bash
cd examples/
ls                    # Browse available examples
cat [example]/README  # Read integration guide
```

### 3. Copy & Customize
```bash
cp -r examples/[example] ~/.claude/[type]/my-extension
# Edit config and implement logic
```

## Example Categories

### Plugins
- Slack integration
- Discord bot
- API bridge
- External tool wrapper

### Hooks
- Pre-commit validation
- Auto-formatting
- Deployment triggers
- Notification hooks

### Skills
- Code review
- Documentation generation
- Test automation
- Performance analysis

### Prompts
- Code style guide
- Architecture review
- Security checklist
- Testing strategy

### Commands
- Deploy workflow
- Backup script
- Log analyzer
- Report generator

## Contributing Examples

To add an example:
1. Create folder: `examples/[category]/[example-name]/`
2. Include README with setup steps
3. Add working, tested code
4. Link from main Examples README
5. Submit PR

See [CONTRIBUTING.md](../CONTRIBUTING.md) for full guidelines.

## Resources

- [CONTRIBUTING.md](../CONTRIBUTING.md)
- [Main README](../README.md)
