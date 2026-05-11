# Architecture

Claudifying is designed as a distributed, symlink-based extension repository. This document explains the organizational principles and directory structure.

## Design Philosophy

**Centralized Source, Global Distribution**
- All extensions live in this repo
- Installed via symlinks to `~/.claude/` (global scope)
- Works in ALL projects without duplication
- Updates propagate instantly via `git pull`

**Community-Driven Organization**
- Clear namespacing by function type
- Predictable file structure
- Extensible categories (audio, video, image, etc.)
- Easy for contributors to add extensions

**Production-Ready Quality**
- Documentation required for all extensions
- Testing standards enforced
- License compliance mandatory
- Security best practices baked in

## Directory Structure

```
claudifying/
├── .claude/                    # Claude Code configuration
│   ├── settings.json          # Project settings
│   ├── MEMORY.md              # Memory index
│   └── memory/                # Project context files
│
├── skills/                     # Invocable tools (/skill-name)
│   ├── code-git-create-repo/  # GitHub repo creation
│   ├── code-optmz-caveman/    # Code optimization
│   ├── code-optmz-graph/      # Knowledge graph generation
│   ├── tools-statusline/      # Statusline tool
│   ├── tools-audio/           # (Placeholder for audio tools)
│   ├── tools-video/           # (Placeholder for video tools)
│   └── tools-image/           # (Placeholder for image tools)
│
├── plugins/                    # System extensions
│   ├── plugin-template/       # Template for new plugins
│   └── README.md              # Plugin guidelines
│
├── hooks/                      # Event-driven automation
│   ├── hook-template/         # Template for new hooks
│   └── README.md              # Hook guidelines
│
├── prompts/                    # Reusable prompt templates
│   ├── prompt-template/       # Template for new prompts
│   └── README.md              # Prompt guidelines
│
├── commands/                   # CLI commands
│   ├── command-template/      # Template for new commands
│   └── README.md              # Command guidelines
│
├── examples/                   # Integration guides & samples
│   ├── hook-setup/
│   ├── skill-creation/
│   └── README.md
│
├── docs/                       # Documentation
│   ├── ARCHITECTURE.md (this file)
│   ├── CONTRIBUTING.md
│   └── guides/
│
├── install.sh                  # Global installer
├── uninstall.sh                # Global uninstaller
├── INSTALL.md                  # Installation guide
├── CONTRIBUTING.md             # Contributing guide
├── CLAUDE.md                   # Project instructions
├── README.md                   # Project overview
├── LICENSE                     # MIT License
└── .gitignore
```

## Core Concepts

### 1. Skills — Invocable Tools

**Purpose:** Reusable task modules called explicitly by users.

**Invocation:** `/skill-name [args]`

**Location:** `skills/[namespace]-[function]/`

**Examples:**
```bash
/code-git-create-repo my-project
/code-optmz-caveman
/code-optmz-graph code.js
```

**Structure:**
```
skills/code-git-create-repo/
├── README.md           # Usage, examples, config
├── SKILL.md            # Skill definition
├── setup.sh            # Implementation
└── config.json         # Configuration
```

### 2. Plugins — System Extensions

**Purpose:** Persistent integrations that extend Claude Code.

**Usage:** Auto-loaded, integrated into UI/workflow

**Location:** `plugins/[plugin-name]/`

**Examples:**
- Slack integration
- GitHub webhook handler
- External API bridge

**Structure:**
```
plugins/slack-integration/
├── README.md
├── plugin.json         # Plugin manifest
├── src/                # Implementation
└── config.example.json
```

### 3. Hooks — Event Automation

**Purpose:** Scripts triggered by Claude Code events.

**Events:** startup, pre_commit, post_commit, command, error

**Location:** `hooks/[hook-name]/`

**Configuration:** Reference in `~/.claude/settings.json`

**Structure:**
```
hooks/pre-commit-validator/
├── README.md
├── hook.sh             # Script
└── config.json
```

### 4. Prompts — Reusable Templates

**Purpose:** System prompts and prompt templates for specific tasks.

**Usage:** Referenced in CLAUDE.md or loaded via CLI

**Location:** `prompts/[category]-[name]/`

**Examples:**
- Code review prompts
- Documentation templates
- Security checklists

**Structure:**
```
prompts/code-review/
├── README.md
├── prompt.md           # Template with variables
└── examples/
```

### 5. Commands — CLI Tools

**Purpose:** Custom slash commands and workflow scripts.

**Usage:** Called like `/command-name`

**Location:** `commands/[command-name]/`

**Structure:**
```
commands/deploy-service/
├── README.md
├── command.sh
└── references/
```

## Naming Conventions

### Namespaces

Extensions use prefix namespaces for organization:

| Prefix | Purpose | Examples |
|--------|---------|----------|
| `/code-*` | Code & GitHub tools | `/code-git-create-repo`, `/code-optmz-caveman`, `/code-optmz-graph` |
| `/tools-audio-*` | Audio processing | `/tools-audio-transcribe`, `/tools-audio-synthesize` |
| `/tools-video-*` | Video processing | `/tools-video-edit`, `/tools-video-generate` |
| `/tools-image-*` | Image processing | `/tools-image-generate`, `/tools-image-analyze` |

**Rules:**
- All lowercase
- Hyphens, no spaces
- Functional name after prefix
- Example: `/tools-audio-transcribe` (not `/toolsaudiotranscribe`)

### Files & Directories

- **Skills:** `skills/[prefix]-[name]/` — e.g., `skills/code-git-create-repo/`
- **Plugins:** `plugins/[name]/` — e.g., `plugins/slack-integration/`
- **Hooks:** `hooks/[name]/` — e.g., `hooks/pre-commit-validator/`
- **Prompts:** `prompts/[category]/[name]/` — e.g., `prompts/code-review/security/`
- **Commands:** `commands/[name]/` — e.g., `commands/deploy-service/`

## Installation & Distribution

### Symlink Architecture

```
Repo (source of truth)
├── skills/
│   ├── code-git-create-repo/
│   └── code-optmz-graph/
└── plugins/
    └── ...
        ↓ symlinks ↓
~/.claude/ (global scope)
├── skills/
│   ├── code-git-create-repo → /path/to/claudifying/skills/code-git-create-repo
│   └── code-optmz-graph → /path/to/claudifying/skills/code-optmz-graph
└── plugins/
    └── ...
```

### Installation Flow

1. **User clones repo**
   ```bash
   git clone https://github.com/pauldx/claudifying.git
   cd claudifying
   ```

2. **Runs installer**
   ```bash
   ./install.sh
   ```

3. **Symlinks created in `~/.claude/`**
   - Skills available globally
   - Plugins auto-loaded
   - Hooks configurable
   - Prompts accessible

4. **Extensions work in ALL projects**
   ```bash
   cd any/project && /code-git-create-repo
   ```

5. **Updates are instant**
   ```bash
   cd claudifying && git pull  # Extensions update everywhere
   ```

### Why Symlinks?

**Benefits:**
- ✅ Single source of truth
- ✅ No duplication
- ✅ Instant updates via git pull
- ✅ Easy to contribute (PR to one place)
- ✅ Version controlled
- ✅ Minimal disk usage

**Alternatives considered:**
- ❌ Copy files: Duplicates, manual updates
- ❌ Submodules: Complex, slower
- ❌ Package manager: External dependency

## Extension Quality Standards

### Required for All Extensions

1. **Clear README.md**
   - Purpose and use cases
   - Installation instructions
   - Working examples (2-3)
   - Configuration guide
   - Dependencies (with licenses)
   - Troubleshooting

2. **Working Code**
   - Tested locally
   - No hardcoded secrets
   - Compatible with latest Claude Code
   - Proper error handling

3. **License Compliance**
   - MIT by default
   - Disclose if different
   - List all dependencies
   - Include LICENSE file if non-MIT

4. **Documentation**
   - SKILL.md/plugin.json with metadata
   - Examples in examples/ directory
   - Configuration templates
   - Comments for non-obvious logic

### Review Checklist

- [ ] Directory structure correct
- [ ] README complete and accurate
- [ ] Examples work and are copy-paste ready
- [ ] Dependencies listed with versions and licenses
- [ ] No secrets or hardcoded values
- [ ] Tests passing (if applicable)
- [ ] Naming follows conventions
- [ ] LICENSE file included (if non-MIT)
- [ ] No duplicates with existing extensions

## Security Considerations

### What NOT to Commit

- `settings.local.json` — user-specific settings
- `.env` files — local configuration
- API keys, tokens, credentials
- Private SSH keys
- Database passwords
- Personal configuration

### Extension Security

- **No hardcoded secrets** — Use environment variables
- **Input validation** — Sanitize user input
- **Safe defaults** — Don't assume trust
- **Disclose dependencies** — All libs must be listed
- **License compliance** — No GPL without disclosure

### Repository Security

- **Pre-commit hooks** — Scan for secrets
- **Access control** — Maintain contributor standards
- **Backups** — Auto-backup on force install
- **Audit trail** — Git history for all changes

## Extension Patterns

### Skill Pattern

```
skills/namespace-function/
├── SKILL.md              # Metadata
├── README.md             # Usage guide
├── implementation.*      # Code (bash, js, py)
└── config.json           # Configuration
```

### Plugin Pattern

```
plugins/name/
├── plugin.json           # Manifest
├── README.md
├── src/
│   └── index.js
└── config.example.json
```

### Hook Pattern

```
hooks/name/
├── hook.sh               # Executable
├── README.md
└── config.json
```

## Extensibility

### Adding New Namespaces

To add a new category:

1. Create directory: `skills/[namespace]-*/`
2. Add README.md explaining category
3. Accept contributions following conventions
4. Update CONTRIBUTING.md with namespace rules

**Example:** Adding `/research-*` for research tools
```
skills/research-*/
├── research-arxiv/       # Papers from arXiv
├── research-scholar/     # Google Scholar integration
└── research-pubmed/      # PubMed literature
```

### Adding New Extension Types

To add a new type (beyond skills/plugins/hooks/prompts/commands):

1. Create directory: `[type]/`
2. Add `[type]/README.md` explaining type
3. Add template: `[type]/_template/`
4. Update `install.sh` to handle new type
5. Document in ARCHITECTURE.md

## Developer Workflow

### Creating an Extension

1. **Pick type:** skill, plugin, hook, prompt, or command
2. **Choose namespace:** `/code-*`, `/tools-*`, `/tools-[category]-*`
3. **Create directory:** Follow naming conventions
5. **Implement:** Write code + README
6. **Test:** Verify locally
7. **Commit:** Use conventional commit format
8. **Push & PR:** Submit to claudifying

### Local Development

```bash
# Clone repo
git clone https://github.com/pauldx/claudifying.git
cd claudifying

# Create feature branch
git checkout -b feature/my-skill

# Create extension
mkdir skills/code-my-feature
# ... add files ...

# Install locally (optional)
./install.sh --force

# Test
cd any/project
/code-my-feature

# Commit
git add skills/code-my-feature
git commit -m "Add: code-my-feature - description"

# Push & create PR
git push origin feature/my-skill
```

## Technical Debt & Future

### Current Limitations

- Symlinks require Unix-like OS (Linux/macOS)
- Windows compatibility via WSL
- Single-language (mostly Bash/JavaScript)

### Planned Improvements

- [ ] Windows native symlink support
- [ ] Package manager integration
- [ ] Auto-discovery of new extensions
- [ ] Community marketplace
- [ ] Analytics on usage

## References

- [Claude Code Documentation](https://code.claude.com)
- [Contributing Guide](../CONTRIBUTING.md)
- [Installation Guide](../INSTALL.md)

---

**Version:** 1.0
**Last Updated:** 2026-05-03
**Maintainer:** Debashis Paul (@pauldx)
