# claudifying

Unified Claude Code extension library — tools, skills, plugins, prompts, agents, commands, hooks, and rules for accelerated development workflows.

All extensions prefixed with `cf-` for easy namespace organization.

## 🔄 Active Branches

### updating-more-skills-plugins-and-agents (merged to main)
- 1,544 skills organized across 20+ category folders (01-20 marketplace + native + cf-* domains)
- 500 marketplace skills consolidated and reorganized from flat structure
- Auto-update feature: post-merge hook syncs marketplace changes automatically
- install.sh configured for git hooks (core.hooksPath)

### merging-plugins (in progress)
- 457 marketplace plugins organized into 18 category folders
- 15 native external plugins isolated in external/ folder
- Plugins consolidated from marketplace source
- plugins-merged removed (catalog-only)
- Auto-update structure pending (similar to skills)

## 📝 Local Settings (NOT committed to repo)

Personal/local configuration goes in `.claude/CLAUDE.md`:
- User information (name, email)
- API keys & credentials
- Development environment setup
- Local preferences

⚠️ **`.claude/CLAUDE.md` is in .gitignore** — stays on your machine only. Never commit secrets.

See `.claude/CLAUDE.md` for template.

---

## 🏗️ Architecture Patterns

### AnalyzerBase Template (45 plugins)

All analyzer-pattern plugins inherit from a single `AnalyzerBase` class in `plugins/_shared/analyzer_base.py`. This eliminates 240+ lines of boilerplate per plugin.

**Pattern shape:**
```python
class YourAnalyzer(AnalyzerBase):
    def analyze_content(self, file_path: Path) -> None:
        """Domain-specific logic only - everything else inherited."""
        # Parse files, extract metrics, classify issues
        pass
```

**Inherited from base:**
- `analyze_directory()` — walk directory, dispatch to analyze_content()
- `analyze_file()` — single-file analysis
- `generate_recommendations()` — issue scoring + severity
- `generate_report()` — structured markdown output
- `run_cli()` — standard CLI interface (--help, --output, --json)
- `self.stats` dict — accumulates file count, sizes, issue types across run

**Adding a new analyzer:**
1. Create `plugins/<category>/<plugin>/scripts/<analyzer>.py`
2. Subclass `AnalyzerBase`, override `analyze_content()`
3. Import: `from analyzer_base import AnalyzerBase`
4. Run: `python <analyzer>.py --help` (CLI auto-wired)

**Plugins using pattern:** 45 across database, testing, security, performance, AI/ML, examples
- **Database:** rollback-analyzer, deadlock-detector, audit-logger, index-advisor, sql-optimizer
- **Testing:** test-coverage-analyzer, mutation-test-runner, regression-tracker, visual-regression-tester
- **Performance:** response-time-tracker, memory-leak-detector, cpu-monitor, throughput-analyzer
- **AI/ML:** sentiment-analysis, feature-engineering, computer-vision, nlp-analyzer, deep-learning-optimizer
- **Security:** access-control-auditor, security-headers-analyzer

See `plugins/_shared/MIGRATION_GUIDE.md` for before/after comparison.

---

## 1. Quick Start

Install all extensions (1,544 skills, 335 commands, 5 agents, 7 hooks, 585 plugins):
```bash
./install.sh            # Symlink all extensions into ~/.claude/ (global)
./install.sh --dry-run  # Preview without making changes
./install.sh --force    # Replace existing conflicts (backs up originals)
./uninstall.sh          # Remove all symlinks from this repo
```

Extensions install globally so they work in **all repos** — not just this one.

Browse organized catalogs (1,000+ total extensions):
- **[Complete Index](./INDEX.md)** — Master navigator for all extensions
- **[Skills by Category](./skills/)** — 1,544 skills organized into 20+ categories:
  - **Marketplace numbered** (~497 skills): 01-devops-basics through 20-enterprise-workflows
  - **Marketplace cf-* domains** (~834 skills): analytics, AI/ML, design, development, media, productivity, +more
  - **Native** (51 skills): Core claudifying tools + extended skills
- **[Plugins Catalog](./plugins/CATALOG.md)** — Install: `ccpi install <plugin-name>`

## 2. Skills (via `/cf-command`)

**Core Workflow Skills:**
- `/cf-code-review` — Structured code review: bugs, security, maintainability
- `/cf-refactor` — Targeted refactoring with test verification between steps
- `/cf-security-audit` — OWASP-based security scan + secret detection
- `/cf-test-writer` — Generate framework-matching tests with full coverage

**Coding Tools (original claudifying):**
- `/cf-code-optmz-caveman` — Performance/readability optimization (caveman mode feedback)
- `/cf-code-optmz-graph` — Build knowledge graph from folder structure
- `/cf-tools-extract-x <url>` — Extract X.com post content (text, author, date, media)
- `/cf-tools-image-convert-svg-png` — Convert SVG to retina PNG via headless Chrome
- `/cf-tools-git-create-repo` — Create + initialize git repositories
- `/cf-tools-audio`, `/cf-tools-video`, `/cf-tools-image`, `/cf-tools-statusline` — Media/system tools

**Coding Skills (Extended):**
- `/cf-tools-git-branch-cleanup` — Clean up merged branches
- `/cf-tools-system-cleanup-cache` — Remove cache/build artifacts
- `/cf-devops` — DevOps infrastructure analysis
- `/cf-mcp-expert` — MCP protocol expertise
- `/cf-optimize-performance` — Performance optimization patterns
- `/cf-plan-gate` — Pre-implementation planning verification
- `/cf-release-manager` — Release coordination and deployment
- `/cf-tdd-gate` — TDD workflow enforcement
- `/cf-workflow-auto` — Automate development workflows

**Research Skills (Extended):**
- `/cf-competitive-intel` — Competitive analysis and intelligence
- `/cf-research-deep` — Deep research and exploration
- `/cf-knowledge-structure` — Build knowledge structures from research
- `/cf-onchain` — On-chain and blockchain research
- `/cf-source-validation` — Validate and verify research sources

**Tools Skills (Extended):**
- `/cf-tools-pdf-create` — Generate PDFs from content
- `/cf-tools-md-obsidian` — Update Obsidian vault from external sources

**Diagram Tools (Extended):**
- `/cf-tools-diagram-excalidraw` — Generate Excalidraw diagrams
- `/cf-tools-diagram-flowchart` — Create flowchart / Mermaid diagrams
- `/cf-tools-diagram-infographic` — Design infographics
- `/cf-tools-diagram-graphify` — Convert specs/code to knowledge graphs (95% token savings)
- `/cf-ui-ux` — UI/UX design patterns and guidelines

**Video Tools (Extended):**
- `/cf-tools-video-captions` — Generate video captions / SRT subtitles
- `/cf-tools-video-compress` — Compress video, re-encode, convert formats (ffmpeg)
- `/cf-tools-video-dub` — AI-powered video dubbing (Whisper + Edge TTS)
- `/cf-tools-video-editing-plan` — Plan video editing workflows
- `/cf-tools-video-extract` — Download/extract videos (incl. X.com)
- `/cf-tools-video-hook-generator` — Create compelling video hooks
- `/cf-tools-video-join` — Merge / concatenate video clips (ffmpeg)
- `/cf-tools-video-script` — Write video scripts

**Worktree Workflow (Extended):**
- `/cf-tools-git-worktree-init` — Create parallel worktrees for concurrent dev
- `/cf-tools-git-worktree-check` — Worktree status across branches
- `/cf-tools-git-worktree-deliver` — Push + PR from worktree branch
- `/cf-tools-git-worktree-cleanup` — Prune merged/stale worktrees

**Writing Skills (Extended):**
- `/cf-content-repurpose` — Repurpose content across formats
- `/cf-copywriting` — Professional copywriting patterns
- `/cf-scqa` — Situation-Complication-Question-Answer writing framework
- `/cf-summary-compressor` — Compress text intelligently
- `/cf-tone-enforcer` — Enforce consistent tone in writing

## 3. Commands (via `/cf-command`)

- `/cf-bootstrap <type> <name>` — Scaffold new command/skill/agent/hook/component
- `/cf-document [file|directory|project]` — Auto-generate or update docs (README, API reference, inline)
- `/cf-review [file|branch]` — Code review on current diff or staged changes
- `/cf-test-all [filter]` — Run full test suite (auto-detects Jest, pytest, Go, Rust, etc.)
- `/cf-triage-pr-review <owner>/<repo>#<pr_number>` — Process automated GitHub PR review comments

## 3.5. Marketplace Commands (via `/cf-<command>`)

**329 marketplace commands** prefixed with `cf-` for namespace consistency. All available as `/cf-<command>`:

**Productivity (8):** `/cf-todo`, `/cf-timer`, `/cf-note`, `/cf-calendar`, `/cf-reminders`, `/cf-bookmark`, `/cf-dictionary`, `/cf-calculator`

**Development & Code (12):** `/cf-snippets`, `/cf-format`, `/cf-lint`, `/cf-test`, `/cf-debug`, `/cf-api-test`, `/cf-regex`, `/cf-database`, `/cf-git-assist`, `/cf-dependency`, `/cf-docker-cli`, `/cf-env-manager`

**Writing & Content (10):** `/cf-grammar-check`, `/cf-markdown`, `/cf-word-count`, `/cf-paraphrase`, `/cf-summary`, `/cf-outline`, `/cf-tone-check`, `/cf-citation`, `/cf-template`, `/cf-glossary`

**Data & Analytics (10):** `/cf-csv-tools`, `/cf-json-tools`, `/cf-xml-tools`, `/cf-sql-query`, `/cf-chart`, `/cf-stats`, `/cf-conversion`, `/cf-comparison`, `/cf-aggregation`, `/cf-validation`

**Research & Learning (8):** `/cf-search`, `/cf-wikipedia`, `/cf-scholar`, `/cf-translation`, `/cf-explain`, `/cf-compare`, `/cf-timeline`, `/cf-mindmap`

See **[commands/CATALOG.md](./commands/CATALOG.md)** for full catalog + usage examples.

## 4. Agents

Specialized subagents for code analysis and operations (5 total: 4 native + 1 marketplace):

**Native Agents (4):**
- **cf-code-reviewer** — Reviews diffs for bugs, security issues, maintainability problems
- **cf-security-auditor** — Scans code for OWASP Top 10, hardcoded secrets, dependency CVEs
- **cf-devops-sre** — Analyzes infrastructure, CI/CD, deployments, operational readiness
- **cf-test-writer** — Generates tests matching project frameworks and conventions

**Marketplace Agents (1):**
- **cf-skill-auditor** — Audits and validates skill implementations

Agents are paired with skills but can also be invoked independently. Auto-update syncs marketplace agents on every `git pull` (if .claude/agents/ modified).

Manual update:
```bash
./update-marketplace-agents.sh
```

## 5. Hooks

Automated on git/tool events:

- **pre-commit-secret-scan.sh** — Blocks commits with exposed AWS keys, GitHub tokens, private keys, etc.
- **post-tool-autoformat.sh** — Auto-formats code after edits (Prettier, Black, gofmt, rustfmt)
- **session-start-context.sh** — Shows branch, uncommitted changes, command/skill count on session start
- **stop-verify.sh** — Reminds to verify work before finishing (tests, regressions, TODOs)

## 6. Rules

Conditional guidance applied to specific contexts:

- **commands-and-skills.md** — How to author new commands/skills (frontmatter, naming, gotchas)
- **git-workflow.md** — Git conventions: branch naming, commit messages, PR practices

## 7. Installation & Distribution

**Directory structure:**
```
.claude/
├── agents/           # Subagent definitions (cf-code-reviewer, cf-security-auditor, cf-devops-sre, cf-test-writer)
├── commands/         # Slash commands
│   ├── general/      # cf-bootstrap, cf-document, cf-review, cf-test-all
│   ├── pr-workflows/ # cf-triage-pr-review
│   └── marketplace/  # 48 cf-prefixed marketplace commands (cf-todo, cf-search, etc.)
├── hooks/            # Pre/post-commit, session hooks
├── rules/            # Git workflow, command authoring guidelines
└── skills/           # 1,544 skills organized by category

skills/              # 1,544 skills organized by marketplace category + native
├── 01-devops-basics/        # 25 devops foundational skills
├── 02-devops-advanced/      # 25 devops advanced skills
├── 03-security-fundamentals/ # 25 security basics
├── ... (01-20 marketplace)
├── 20-enterprise-workflows/ # 25 enterprise automation
└── native/                  # 213 native claudifying skills (core + extended)

plugins/             # 472 plugins organized by category (15 native + 457 marketplace)
├── ai-agency/               # 8 plugins
├── ai-ml/                   # 37 plugins (36 marketplace + cf-context7 native)
├── api-development/         # 27 plugins (25 marketplace + cf-greptile, cf-laravel-boost native)
├── business-tools/          # 27 plugins (22 marketplace + cf-asana, cf-discord, cf-imessage, cf-linear, cf-telegram native)
├── crypto/                  # 28 plugins
├── database/                # 29 plugins
├── design/                  # 7 plugins
├── devops/                  # 44 plugins (39 marketplace + cf-firebase, cf-github, cf-gitlab, cf-terraform native)
├── examples/                # 6 plugins (5 marketplace + cf-fakechat native)
├── mcp/                     # 10 plugins
├── packages/                # 5 plugins
├── performance/             # 25 plugins
├── productivity/            # 23 plugins
├── saas-packs/              # 114 plugins
├── security/                # 31 plugins (30 marketplace + cf-serena native)
├── skill-enhancers/         # 9 plugins
└── testing/                 # 30 plugins (29 marketplace + cf-playwright native)
```

All skills + plugins symlinked into `~/.claude/` on install.
Commands → `~/.claude/commands/`, Agents → `~/.claude/agents/`, etc.

## 8. Conventions

- **Kebab-case with cf- prefix**: `cf-code-review`, `cf-tools-extract-x`, etc.
- **Skill/Command triggers** use `/cf-skill-name` in chat
- **Agents** are YAML definitions invoked by Claude (not user-triggered directly)
- **Hooks** are bash scripts executed on git/tool events (configure in settings.json)
- **Rules** are markdown files with `<important if="condition">` gates

## 9. Adding New Items

### New Skill
```bash
mkdir -p .claude/skills/cf-my-skill
cat > .claude/skills/cf-my-skill/SKILL.md <<EOF
---
name: cf-my-skill
description: When user asks to X, activate this skill for Y
---
# Skill content here
EOF
./install.sh
```

### New Command
```bash
cat > .claude/commands/general/cf-my-command.md <<EOF
---
description: Brief description of what this does
user-invocable: true
argument: [optional args]
---
# Command steps here
EOF
./install.sh
```

### New Agent
```bash
cat > .claude/agents/cf-my-agent.yml <<EOF
name: cf-my-agent
description: What this agent does
model: sonnet
instructions: |
  Agent instructions here
EOF
./install.sh
```

## 10. Updating Extensions

All symlinked — changes are **instantly available** everywhere.

```bash
cd /path/to/claudifying
git pull
# Changes are live immediately (no reinstall needed)
```

### Auto-Update Marketplace Extensions

Marketplace extensions auto-sync from upstream on every `git pull`:

**Skills:**
- **Post-merge hook** (`.claude/hooks/post-merge-update-skills.sh`) triggers on pull
- **Update script** (`update-marketplace-skills.sh`) clones and syncs marketplace changes
- Only syncs if skills/ was modified in pull (minimal overhead)

**Plugins:**
- **Post-merge hook** (`.claude/hooks/post-merge-update-plugins.sh`) triggers on pull
- **Update script** (`update-marketplace-plugins.sh`) clones and syncs marketplace changes
- Only syncs if plugins/ was modified in pull (minimal overhead)

**Agents:**
- **Post-merge hook** (`.claude/hooks/post-merge-update-agents.sh`) triggers on pull
- **Update script** (`update-marketplace-agents.sh`) clones and syncs marketplace changes
- Only syncs if .claude/agents/ was modified in pull (minimal overhead)

Manual update anytime:
```bash
./update-marketplace-skills.sh   # Update skills
./update-marketplace-plugins.sh  # Update plugins
./update-marketplace-agents.sh   # Update agents
```

## 11. Removing Extensions

Remove everything:
```bash
./uninstall.sh
```

Remove one skill/command/agent:
```bash
rm ~/.claude/skills/cf-skill-name
rm ~/.claude/commands/general/cf-command-name.md
rm ~/.claude/agents/cf-agent-name.yml
```

## 12. Marketplace Catalogs

**Integrated from marketplace:** 329 slash commands + 55 MCP servers + **570 plugins** (merged) + 1,331 skills.

All marketplace commands available as `/cf-<command>` for namespace consistency.
All plugins available as `/cf-<plugin>` for namespace consistency.

Install any marketplace item via:
```bash
# Marketplace Commands (cf-prefixed)
/cf-todo [args]
/cf-search [query]
...

# MCP Servers
npm install <server-package>
/mcp add <server-name>

# Plugins & Skills
ccpi install <plugin-name>
/plugin install <plugin-name>
```

- **[Commands Catalog (5 native + 329 marketplace + 1 pr-workflows)](./commands/CATALOG.md)** — 25+ categories
- **[MCP Servers Catalog (55)](./mcp/CATALOG.md)** — 6 categories (DevTools, Databases, APIs, Cloud, Utilities, AI/ML)
- **[Plugins Catalog (472)](./plugins/CATALOG.md)** — 18 categories
- **[Skills Catalog (1,544)](./skills/CATALOG.md)** — 20+ categories

See **[INDEX.md](./INDEX.md)** for complete navigation of all extensions.

## 13. Full Inventory

**Total: 2,478 Extensions** (consolidated single directories for skills + plugins)

| Type | Count | Source |
|------|-------|--------|
| Skills | 1,544 | 213 native + 1,331 marketplace (consolidated in skills/ + .claude/skills/) |
| Plugins | 585 | 15 native external + 570 marketplace (consolidated in plugins/) |
| Commands | 335 | 5 native user-invocable + 329 marketplace + 1 pr-workflows |
| MCP Servers | 55 | Marketplace |
| Agents | 5 | Native + marketplace cf-skill-auditor |
| Hooks | 7 | 4 native + 3 post-merge auto-update |
| Rules | 2 | Native |

**Native Skills Breakdown (213):**

Core (24):
- Workflow (4): cf-code-review, cf-refactor, cf-security-audit, cf-test-writer
- Code (2): cf-code-optmz-caveman, cf-code-optmz-graph
- Gates/advisory (5): cf-plan-gate, cf-tdd-gate, cf-devops, cf-mcp-expert, cf-ui-ux
- Process (3): cf-release-manager, cf-optimize-performance, cf-workflow-auto
- Research (5): cf-research-deep, cf-competitive-intel, cf-knowledge-structure, cf-onchain, cf-source-validation
- Writing (5): cf-copywriting, cf-content-repurpose, cf-scqa, cf-summary-compressor, cf-tone-enforcer

Tools (189):
- Video file-ops (10): cf-tools-video-{trim, thumbnail, rotate, speed, resize, mute, gif, watermark, loop, metadata}
- Video creative (8): cf-tools-video-{captions, compress, dub, editing-plan, extract, hook-generator, join, script}
- Audio (12): cf-tools-audio-{convert, trim, merge, normalize, extract-from-video, transcribe, tts, fade, speed, denoise, waveform, metadata}
- Image (17): cf-tools-image-{resize, convert, compress, crop, rotate, strip-metadata, heic-to-jpg, favicon, thumbnail, watermark, palette, diff, fetch-logo, bg-remove, ocr, upscale, convert-svg-png}
- PDF (8): cf-tools-pdf-{create, extract-text, merge, split, watermark, compress, to-images, info}
- Markdown (9): cf-tools-md-{obsidian, toc, lint, to-html, to-docx, to-slides, render-preview, mermaid-render, syntax-highlight}
- Diagram (4): cf-tools-diagram-{excalidraw, flowchart, infographic, graphify}
- Data (10): cf-tools-data-{csv-to-json, json-to-csv, csv-filter, csv-sort, json-flatten, json-merge, yaml-to-json, json-validate, json-query, csv-diff}
- Text (8): cf-tools-text-{diff, dedupe, regex-replace, case-convert, slug-generate, base64, urlencode, sort-lines}
- Net (5): cf-tools-net-{http-request, dns-lookup, ssl-check, ip-info, whois-lookup}
- Hash (4): cf-tools-hash-{sha256, hash-file, uuid, jwt-decode}
- Date (3): cf-tools-date-{parse, convert-tz, cron-explain}
- Web (6): cf-tools-web-{lighthouse-audit, html-format, css-minify, js-minify, sitemap-generate, og-image-render}
- System (6): cf-tools-system-{cleanup-cache, statusline, disk-free, top-cpu, env-dump, brew-orphan}
- Docker (6): cf-tools-docker-{prune, stats, compose-validate, cleanup-images, run-pretty, logs-tail}
- K8s (4): cf-tools-k8s-{pod-logs, pod-restart, get-events, kubectx-switch}
- AWS (4): cf-tools-aws-{profile-switch, s3-ls, ec2-status, costs-summary}
- GCP (4): cf-tools-gcp-{profile-switch, gcs-ls, run-list, costs-summary}
- Git extras (14): cf-tools-git-{create-repo, branch-cleanup, worktree-{init,check,cleanup,deliver}, undo-last, rebase-undo, conflict-helper, blame-search, log-pretty, diff-stats, stash-helper, tag-version}
- Productivity (6): cf-tools-productivity-{qr-generate, qr-decode, clipboard-copy, color-picker, lorem-ipsum, password-gen}
- Code (3): cf-tools-code-{count-loc, find-todo, find-fixme}
- Archive (4): cf-tools-archive-{tar-create, tar-extract, zip-create, zip-extract}
- Crypto (8): cf-tools-crypto-{ssh-keygen, gpg-{encrypt,decrypt,sign,verify}, openssl-keygen, password-hash-bcrypt, rsa-keygen}
- Shell (6): cf-tools-shell-{which-bin, find-file, watch-dir, port-listening, kill-port, env-edit}
- Notify (5): cf-tools-notify-{slack-send, discord-send, macos-notify, email-send, telegram-send}
- AI (6): cf-tools-ai-{anthropic-call, openai-call, ollama-call, prompt-test, embedding-generate, models-list}
- Browser (5): cf-tools-browser-{screenshot-url, page-text, html-fetch, pdf-print-url, open-url}
- SAST (5): cf-tools-sast-{bandit-scan, eslint-security, semgrep-scan, gosec-scan, trivy-scan}
- Extract (1): cf-tools-extract-x

**Native External Plugins (15):**
cf-asana, cf-context7, cf-discord, cf-fakechat, cf-firebase, cf-github, cf-gitlab, cf-greptile, cf-imessage, cf-laravel-boost, cf-linear, cf-playwright, cf-serena, cf-telegram, cf-terraform

**Consolidated Marketplace Extensions:**
- [Skills (500)](./skills/CATALOG.md) — 20 categories (all 500 marketplace skills now in unified skills/ directory)
- [Plugins (570)](./plugins/CATALOG.md) — categorized (all 570 marketplace plugins in unified plugins/ directory)
- [Slash Commands (48)](./commands/CATALOG.md) — 5 categories (Productivity, Development, Writing, Data, Research)
- [MCP Servers (55)](./mcp/CATALOG.md) — 6 categories (DevTools, Databases, APIs, Cloud, Utilities, AI/ML)
