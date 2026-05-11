# Prompts

Reusable system prompts and prompt templates for common tasks.

## What's a Prompt?

Prompts are:
- System prompts for specific domains
- Prompt templates with variables
- Claude Code configuration snippets
- Task-specific instructions

## Directory Structure

```
prompts/
├── prompt-name/
│   ├── README.md
│   ├── prompt.md (or .txt)
│   ├── config.json (optional)
│   └── LICENSE (optional)
```

## Prompt Format

### Markdown Prompt
```markdown
---
name: Prompt Name
description: What this prompt does
version: 1.0.0
tags: [tag1, tag2]
---

Your prompt content here.

## Variables
- {{variable}} — description

## Usage
Load in CLAUDE.md or via CLI
```

## How to Use

### In CLAUDE.md
```markdown
# Project Rules
{{load: prompts/prompt-name/prompt.md}}
```

### Via CLI
```bash
cat prompts/prompt-name/prompt.md
```

## Creating a Prompt

See CONTRIBUTING.md for structure and guidelines.

## Available Prompts

(Coming soon — community contributions welcome!)

## Categories

- Code Review
- Documentation
- Testing
- Security
- Performance
- Refactoring

## Resources

- [Claude Prompt Engineering](https://anthropic.com/prompt-engineering)
- [Contributing Guide](../CONTRIBUTING.md)
