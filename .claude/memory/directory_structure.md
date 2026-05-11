---
name: Claudifying Directory Structure
description: Complete directory layout and organization of the repository
type: reference
---

# Claudifying Directory Structure

```
claudifying/
├── .claude/                        # Claude Code configuration
│   ├── settings.json              # Claude Code settings
│   ├── MEMORY.md                  # Memory index
│   └── memory/                    # Memory files
│       ├── project_overview.md
│       ├── contribution_guidelines.md
│       ├── licensing.md
│       ├── directory_structure.md
│       ├── extension_types.md
│       ├── submission_process.md
│       └── testing_standards.md
│
├── plugins/                        # Claude Code plugins
│   └── README.md
│
├── hooks/                          # Hook scripts and configurations
│   └── README.md
│
├── skills/                         # Skill definitions (.skill files)
│   ├── code-git-create-repo.skill # Sample skill
│   ├── code-git-create-repo/      # Skill directory
│   │   ├── README.md
│   │   ├── setup.sh
│   │   └── config.json
│   └── README.md
│
├── prompts/                        # Prompt templates
│   └── README.md
│
├── commands/                       # CLI commands
│   └── README.md
│
├── examples/                       # Integration guides and samples
│   └── README.md
│
├── README.md                       # Project overview
├── CLAUDE.md                       # Claude Code project instructions
├── CONTRIBUTING.md                # Contributing guidelines
├── CONTRIBUTING.md          # Template for new extensions
├── LICENSE                         # MIT License
├── .gitignore                      # Git ignore rules
└── package.json (optional)        # NPM metadata

```

## Directory Purposes

### .claude/
Claude Code configuration and project context.
- `settings.json` — Claude Code harness settings
- `MEMORY.md` — Memory index for this project
- `memory/` — Detailed memory files

### plugins/, hooks/, skills/, prompts/, commands/
Extension storage organized by type.
Each has:
- `README.md` — Usage guide for that type
- Individual extension folders/files

### examples/
Working implementations and integration guides.
Organized by extension type.

### Root Files
- `README.md` — Main project documentation
- `CLAUDE.md` — Instructions for Claude working in this repo
- `CONTRIBUTING.md` — Contribution guidelines
- `CONTRIBUTING.md` — Template for new extensions
- `LICENSE` — MIT license
- `.gitignore` — Git configuration

## File Naming Conventions

- **Skills:** `skill-name.skill` or `skill-name/`
- **Plugins:** `plugin-name/` with plugin.json
- **Hooks:** `hook-name.sh` or `hook-name/hook.sh`
- **Prompts:** `prompt-name.md` or `prompt-name/`
- **Commands:** `command-name.sh` or `command-name/`

All lowercase with hyphens, no spaces.

---

**Created:** 2026-05-03
