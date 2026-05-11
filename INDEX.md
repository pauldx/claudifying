# Claudifying — Unified Extension Library Index

Complete index of all 44 native extensions + 925 marketplace plugins & skills.

---

## 🏠 Native Extensions (Claudifying)

Extensions prefixed with `cf-` — developed and maintained in this repo.

**Total: 44 extensions** across skills, commands, agents, hooks, and rules.

### Quick Navigation

- **[Skills (44)](#native-skills)** — Workflow automation, code tools, research, design, video, writing
- **[Commands (5)](#native-commands)** — Bootstrap, document, review, test, triage PR
- **[Agents (4)](#native-agents)** — Code reviewer, security auditor, DevOps/SRE, test writer
- **[Hooks (4)](#native-hooks)** — Secret scan, auto-format, session context, stop verify
- **[External Plugins (15)](#native-external-plugins)** — Discord, Telegram, GitHub, Linear, etc.
- **[Rules (2)](#native-rules)** — Git workflow, command authoring

For full native extensions documentation, see **[CLAUDE.md](./CLAUDE.md)**.

#### Native Skills

35 SKILL.md-based skills + 9 tool-oriented skills. Full list in [CLAUDE.md — Skills section](./CLAUDE.md#2-skills-via-cf-command).

```
cf-code-review, cf-refactor, cf-security-audit, cf-test-writer
cf-branch-cleanup, cf-cleanup-cache, cf-devops, cf-mcp-expert
cf-optimize-performance, cf-plan-gate, cf-release-manager, cf-tdd-gate, cf-workflow-auto
cf-competitive-intel, cf-research-deep, cf-knowledge-structure, cf-onchain, cf-source-validation
cf-create-pdf, cf-extract-video, cf-graphify, cf-obsidian-update
cf-excalidraw, cf-flowchart, cf-infographic, cf-ui-ux
cf-video-captions, cf-video-editing-plan, cf-video-hook-generator, cf-video-script
cf-content-repurpose, cf-copywriting, cf-scqa, cf-summary-compressor, cf-tone-enforcer
cf-code-optmz-caveman, cf-code-optmz-graph, cf-tools-extract-x, cf-tools-image-convert-svg-png
cf-code-git-create-repo, cf-tools-audio, cf-tools-image, cf-tools-statusline, cf-tools-video
```

#### Native Commands

- `/cf-bootstrap <type> <name>` — Scaffold command/skill/agent/hook
- `/cf-document [file|directory|project]` — Auto-generate docs
- `/cf-review [file|branch]` — Code review on diff or staged changes
- `/cf-test-all [filter]` — Run full test suite (auto-detects Jest, pytest, Go, Rust)
- `/cf-triage-pr-review <owner>/<repo>#<pr>` — Process GitHub PR review comments

#### Native Agents

- **cf-code-reviewer** — Reviews diffs for bugs, security, maintainability
- **cf-security-auditor** — OWASP Top 10, secrets, CVEs
- **cf-devops-sre** — Infrastructure, CI/CD, operational readiness
- **cf-test-writer** — Generates framework-matching tests

#### Native Hooks

- `pre-commit-secret-scan.sh` — Blocks commits with exposed keys/tokens
- `post-tool-autoformat.sh` — Auto-formats code (Prettier, Black, gofmt, rustfmt)
- `session-start-context.sh` — Shows branch, uncommitted changes, extension count
- `stop-verify.sh` — Reminds to verify before finishing

#### Native External Plugins (15)

Installed in `plugins/external/`. See **[CLAUDE.md — Plugins](./CLAUDE.md#official-and-external-plugins)**.

```
cf-asana, cf-context7, cf-discord, cf-fakechat, cf-firebase, cf-github
cf-gitlab, cf-greptile, cf-imessage, cf-laravel-boost, cf-linear
cf-playwright, cf-serena, cf-telegram, cf-terraform
```

#### Native Rules

- **git-workflow.md** — Branch naming, commit messages, PR practices
- **commands-and-skills.md** — How to author new extensions

---

## 🎪 Marketplace Extensions

**609 plugins** + **500 skills** from consolidated marketplace sources.

### Install from Marketplace

All marketplace items installable via:

```bash
# Via CLI
ccpi install <plugin-name>

# Or in Claude Code
/plugin install <plugin-name>@claude-code-plugins-plus
```

### Marketplace Navigation

- **[Slash Commands Catalog (48)](#slash-commands-catalog)** — 5 categories
- **[MCP Servers Catalog (55)](#mcp-servers-catalog)** — 6 categories
- **[Plugins Catalog (425)](#plugins-catalog)** — 17 categories
- **[Skills Catalog (500)](#skills-catalog)** — 20 categories

### Slash Commands Catalog

**48 slash commands** across 5 categories for productivity, development, writing, data, and research.

| Category | Count | Examples |
|----------|-------|----------|
| Productivity | 8 | [View →](./commands/CATALOG.md#productivity) |
| Development & Code | 12 | [View →](./commands/CATALOG.md#development--code) |
| Writing & Content | 10 | [View →](./commands/CATALOG.md#writing--content) |
| Data & Analytics | 10 | [View →](./commands/CATALOG.md#data--analytics) |
| Research & Learning | 8 | [View →](./commands/CATALOG.md#research--learning) |

👉 **Full commands index: [commands/CATALOG.md](./commands/CATALOG.md)**

### MCP Servers Catalog

**55 MCP servers** across 6 categories for connecting to databases, APIs, cloud services, and tools.

| Category | Count | Examples |
|----------|-------|----------|
| DevTools | 8 | [View →](./mcp/CATALOG.md#devtools) |
| Databases | 9 | [View →](./mcp/CATALOG.md#databases) |
| APIs & Web Services | 12 | [View →](./mcp/CATALOG.md#apis--web-services) |
| Cloud & Infrastructure | 8 | [View →](./mcp/CATALOG.md#cloud--infrastructure) |
| Utilities & Helpers | 10 | [View →](./mcp/CATALOG.md#utilities--helpers) |
| AI & Machine Learning | 8 | [View →](./mcp/CATALOG.md#ai--machine-learning) |

👉 **Full MCP servers index: [mcp/CATALOG.md](./mcp/CATALOG.md)**

### Plugins Catalog

**609 plugins** across 48 categories (merged from sibling repo + aitmpl.com collections).

| Category | Count |
|----------|-------|
| AI/ML | 36 |
| DevOps | 35 |
| Claude Plugins Official | 43 |
| Agentsys | 19 |
| Crypto & Blockchain | 26 |
| Database | 26 |
| Skill Enhancers | 27 |
| API Development | 25 |
| Performance | 25 |
| Business Tools | 22 |
| Community | 12 |
| Claude Code LSPs | 24 |
| Testing | 26 |
| MCP | 10 |
| Design | 7 |
| Examples | 5 |
| ... and 32 more categories | ... |

👉 **Full plugins index: [plugins-merged/CATALOG.md](./plugins-merged/CATALOG.md)** (609 plugins)

### MCP Servers Catalog

**55 MCP servers** across 6 categories for connecting to databases, APIs, cloud services, and tools.

| Category | Count | Examples |
|----------|-------|----------|
| DevTools | 8 | [View →](./mcp/CATALOG.md#devtools) |
| Databases | 9 | [View →](./mcp/CATALOG.md#databases) |
| APIs & Web Services | 12 | [View →](./mcp/CATALOG.md#apis--web-services) |
| Cloud & Infrastructure | 8 | [View →](./mcp/CATALOG.md#cloud--infrastructure) |
| Utilities & Helpers | 10 | [View →](./mcp/CATALOG.md#utilities--helpers) |
| AI & Machine Learning | 8 | [View →](./mcp/CATALOG.md#ai--machine-learning) |

👉 **Full MCP servers index: [mcp/CATALOG.md](./mcp/CATALOG.md)**

### Skills Catalog

**500 skills** across 20 categories, 25 skills each.

| Category | Count | Examples |
|----------|-------|----------|
| DevOps Basics | 25 | [View →](./skills/CATALOG.md#01-devops-basics) |
| DevOps Advanced | 25 | [View →](./skills/CATALOG.md#02-devops-advanced) |
| Security Fundamentals | 25 | [View →](./skills/CATALOG.md#03-security-fundamentals) |
| Security Advanced | 25 | [View →](./skills/CATALOG.md#04-security-advanced) |
| Frontend Development | 25 | [View →](./skills/CATALOG.md#05-frontend-dev) |
| Backend Development | 25 | [View →](./skills/CATALOG.md#06-backend-dev) |
| ML Training | 25 | [View →](./skills/CATALOG.md#07-ml-training) |
| ML Deployment | 25 | [View →](./skills/CATALOG.md#08-ml-deployment) |
| Test Automation | 25 | [View →](./skills/CATALOG.md#09-test-automation) |
| Performance Testing | 25 | [View →](./skills/CATALOG.md#10-performance-testing) |
| Data Pipelines | 25 | [View →](./skills/CATALOG.md#11-data-pipelines) |
| Data Analytics | 25 | [View →](./skills/CATALOG.md#12-data-analytics) |
| AWS Skills | 25 | [View →](./skills/CATALOG.md#13-aws-skills) |
| GCP Skills | 25 | [View →](./skills/CATALOG.md#14-gcp-skills) |
| API Development | 25 | [View →](./skills/CATALOG.md#15-api-development) |
| API Integration | 25 | [View →](./skills/CATALOG.md#16-api-integration) |
| Technical Docs | 25 | [View →](./skills/CATALOG.md#17-technical-docs) |
| Visual Content | 25 | [View →](./skills/CATALOG.md#18-visual-content) |
| Business Automation | 25 | [View →](./skills/CATALOG.md#19-business-automation) |
| Enterprise Workflows | 25 | [View →](./skills/CATALOG.md#20-enterprise-workflows) |

👉 **Full skills index: [skills/CATALOG.md](./skills/CATALOG.md)**

---

## 📊 Extension Inventory

| Type | Count | Source |
|------|-------|--------|
| **Skills** | 544 | 44 native + 500 marketplace |
| **Plugins** | 624 | 15 native external + 609 marketplace (merged) |
| **Commands** | 53 | 5 native + 48 marketplace (cf-prefixed) |
| **MCP Servers** | 55 | Marketplace (aitmpl.com/mcps) |
| **Agents** | 4 | Native only |
| **Hooks** | 4 | Native only |
| **Rules** | 2 | Native only |
| **External Plugin Dirs** | 15 | Native |
| | | |
| **TOTAL** | **1,301** | All extensions + merged marketplace |

---

## 🚀 Quick Start

### 1. Install Native Extensions

```bash
cd /path/to/claudifying
./install.sh            # Symlink to ~/.claude/ (global)
./install.sh --dry-run  # Preview without changes
./install.sh --force    # Force overwrite (backs up originals)
```

Extensions are now available in **all repos** (symlinked globally).

### 2. Browse & Install Marketplace Extensions

See **[plugins/CATALOG.md](./plugins/CATALOG.md)** and **[skills/CATALOG.md](./skills/CATALOG.md)** for full catalogs.

Install via:
```bash
ccpi install <plugin-name>
```

Or in Claude Code:
```
/plugin install <plugin-name>@claude-code-plugins-plus
```

### 3. Invoke Extensions

**Native skills:**
```
/cf-code-review
/cf-refactor
/cf-test-writer
...
```

**Marketplace skills:** Triggered by phrase or command in Claude Code (see skill description).

---

## 📝 Documentation

- **[CLAUDE.md](./CLAUDE.md)** — Full native extensions docs, installation, conventions
- **[plugins/CATALOG.md](./plugins/CATALOG.md)** — Searchable plugins index (425)
- **[skills/CATALOG.md](./skills/CATALOG.md)** — Searchable skills index (500)
- **[CONTRIBUTING.md](./CONTRIBUTING.md)** — How to contribute new extensions
- **[docs/](./docs/)** — Additional guides (architecture, agents, etc.)

---

## 🔄 Updating Catalogs

If the source marketplace repo is available, regenerate catalogs:

```bash
node scripts/generate-catalog.mjs /path/to/claude-code-plugins-plus-skills
```

This updates `plugins/catalog.json`, `plugins/CATALOG.md`, `skills/catalog.json`, `skills/CATALOG.md`.

Catalogs are checked in for offline reference.

---

Generated: 2026-05-11 | Source: [claudifying](https://github.com/yourusername/claudifying)
