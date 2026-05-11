---
description: Auto-generate or update documentation for code, commands, or the project
user-invocable: true
argument: [file, directory, or "project"] (optional — defaults to project-level docs)
---

# Auto-Generate Documentation

Generate or update documentation based on the current codebase.

## Step 1: Determine Scope

Based on `$ARGUMENTS` or user input:

- **`project`** (or no argument): Update README.md catalog tables and command reference
- **File path**: Generate inline docs (JSDoc, docstrings, comments) for that file
- **Directory path**: Generate an overview doc for that module/directory
- **`commands`**: Generate a command reference from all command frontmatter
- **`api`**: Generate API reference from endpoint definitions

## Step 2: Gather Information

### For project-level docs:
- Scan all commands and extract frontmatter (description, arguments)
- Scan all skills and extract SKILL.md metadata
- Scan all agents and extract definitions
- Check for changes since last documentation update

### For file-level docs:
- Read the file and understand exports, functions, classes
- Identify parameters, return types, and side effects
- Look at existing tests for usage examples

### For API docs:
- Find route/endpoint definitions
- Extract request/response schemas
- Identify authentication requirements

## Step 3: Generate Documentation

### Project catalog (README.md):
Update the commands and skills tables:

```markdown
| Command | Category | Description |
|---------|----------|-------------|
| `/create-issue` | GitHub | Create a GitHub issue in a repository |
...
```

### File documentation:
Add or update doc comments following the project's convention:
- JavaScript/TypeScript: JSDoc (`/** ... */`)
- Python: Docstrings (`"""..."""`)
- Go: Godoc comments (`// FuncName ...`)
- Bash: Header comments (`# Description: ...`)

### Command reference:
Generate `docs/command-reference.md` with:
- Full description of each command
- Arguments and options
- Usage examples
- Prerequisites

## Step 4: Verify

- Ensure generated docs are accurate against current code
- Check that no existing documentation was accidentally removed
- Present a diff summary of what was added/changed
- Ask the user to review before committing

## Important

- **Never fabricate** — only document what exists in the code
- **Match existing style** — follow the project's documentation conventions
- **Don't over-document** — skip trivial getters/setters and obvious code
