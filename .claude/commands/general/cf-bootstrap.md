---
description: Scaffold a new module, component, or feature with boilerplate
user-invocable: true
argument: <module-type> <name> (e.g., "command create-deploy" or "skill api-monitor")
---

# Bootstrap New Module

Scaffold a new command, skill, agent, or component with the correct structure and boilerplate.

## Step 1: Determine What to Scaffold

Parse `$ARGUMENTS` or ask the user:

1. **What type?**
   - `command` — New slash command
   - `skill` — New multi-file skill
   - `agent` — New agent definition
   - `hook` — New hook script
   - `component` — Generic project component (src/ based)

2. **What name?** — kebab-case (e.g., `deploy-staging`, `api-monitor`)

3. **Which category?** (for commands only)
   - `pr-workflows` — Git/PR workflows
   - `general` — General-purpose utilities
   - New category (creates the directory)

## Step 2: Scaffold Based on Type

### Command
```
.claude/commands/<category>/<name>.md    # From _template.md
```
- Copy `_template.md` and fill in the name and description
- Add frontmatter with `description` and `user-invocable: true`

### Skill
```
.claude/skills/<name>/
  SKILL.md          # From _template/SKILL.md
  scripts/          # Empty directory
  references/       # Empty directory
  assets/           # Empty directory
```

### Agent
```
.claude/agents/<name>.yml
```
- Scaffold with `name`, `description`, `model`, `instructions` fields

### Hook
```
.claude/hooks/<name>.sh
```
- Scaffold with shebang, set -euo pipefail, and event type comment

## Step 3: Post-Scaffold

After creating files:
1. Open the main file for the user to edit
2. If it's a command, remind them to run `./install.sh` to symlink it
3. If it's a skill, remind them to add it to the README catalog
4. Run `./scripts/validate.sh` to confirm the scaffold is valid

## Step 4: Update Documentation

- Add the new item to the README.md catalog table
- If a new category was created, update CLAUDE.md's repo structure section
