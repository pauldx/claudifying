---
name: Extension Types Reference
description: Overview of each extension type - purpose, structure, examples
type: reference
---

# Extension Types

## Plugins
**Purpose:** Extend Claude Code with new tools and integrations.

- Custom integrations (Slack, Discord, external APIs)
- External tool bridges
- Custom tool definitions
- Enhanced workflows

**Structure:**
```
plugins/plugin-name/
├── plugin.json
├── README.md
└── src/index.js
```

## Hooks
**Purpose:** Automate actions in response to Claude Code events.

- Pre/post commit hooks
- Startup/shutdown automation
- Before/after command execution
- Custom workflows

**Types:**
- startup, pre_commit, post_commit, command, error

**Structure:**
```
hooks/hook-name/
├── hook.sh (or .js)
├── README.md
└── config.json
```

## Skills
**Purpose:** Reusable task modules with specialized capabilities.

- Code analysis and review
- Build/deployment workflows
- Testing automation
- Documentation generation
- Custom business logic

**Structure:**
```
skills/skill-name/
├── SKILL.md (or .skill)
├── README.md
├── skill.json
└── src/
```

## Prompts
**Purpose:** Reusable system prompts and prompt templates.

- Domain-specific system prompts
- Prompt templates with variables
- Claude Code configurations
- Task-specific instructions

**Structure:**
```
prompts/prompt-name/
├── prompt.md
├── README.md
└── config.json (optional)
```

## Commands
**Purpose:** Custom CLI commands and workflows.

- Custom CLI tools
- Workflow scripts
- Task runners
- Integration binaries

**Structure:**
```
commands/command-name/
├── command.sh (or .js, .py)
├── README.md
└── config.json
```

## Extension Template

All extensions follow:
- **README.md** — Clear documentation
- **Usage examples** — Working code samples
- **Installation instructions** — Step-by-step guide
- **Dependencies** — Listed with licenses
- **Configuration** — Setup requirements
- **License** — MIT or alternative (disclosed)

---

**Created:** 2026-05-03
