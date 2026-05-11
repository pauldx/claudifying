# Skills

Skills are reusable task modules for Claude Code — specialized capabilities that can be called from prompts or commands.

## What's a Skill?

Skills package reusable functionality:
- Code analysis tasks
- Build/deployment workflows
- Testing frameworks
- Documentation generation
- Custom business logic

## Directory Structure

```
skills/
├── skill-name/
│   ├── SKILL.md (or .skill)
│   ├── README.md
│   ├── skill.json
│   ├── src/
│   │   └── [implementation]
│   └── LICENSE (optional)
```

## Skill Format

### SKILL.md (Recommended)
```markdown
---
name: Skill Name
description: What this skill does
version: 1.0.0
author: Your Name
---

[Skill implementation]
```

## How to Use

### Manual
1. Copy skill to `~/.claude/skills/`
2. Reference by name: `/skill-name [args]`

### In Prompts
```
Use the /skill-name skill to accomplish X
```

## Creating a Skill

See CONTRIBUTING.md for structure and guidelines.

## Available Skills

(Coming soon — community contributions welcome!)

## Resources

- [Claude Code Skills Docs](https://code.claude.com/docs/skills)
- [Contributing Guide](../CONTRIBUTING.md)
