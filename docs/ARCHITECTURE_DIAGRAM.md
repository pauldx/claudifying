# Claudifying — Architecture Diagram & Benefits

---

## System Overview

```mermaid
graph TB
    subgraph REPO["📦 claudifying (git repo)"]
        direction TB
        S[skills/]
        P[plugins/]
        H[hooks/]
        PR[prompts/]
        C[commands/]
        I[install.sh]
    end

    subgraph GLOBAL["🌐 ~/.claude/ (global scope)"]
        direction TB
        GS[skills/]
        GP[plugins/]
        GH[hooks/]
        GPR[prompts/]
    end

    subgraph PROJECTS["🗂️ Any Project on Machine"]
        direction LR
        PRJ1[project-alpha/]
        PRJ2[project-beta/]
        PRJ3[project-gamma/]
    end

    I -->|"symlink"| GS
    I -->|"symlink"| GP
    I -->|"symlink"| GH
    I -->|"symlink"| GPR

    S -.->|"source"| GS
    P -.->|"source"| GP
    H -.->|"source"| GH
    PR -.->|"source"| GPR

    GLOBAL -->|"auto-loaded"| PRJ1
    GLOBAL -->|"auto-loaded"| PRJ2
    GLOBAL -->|"auto-loaded"| PRJ3

    GIT[("git pull")] -->|"updates all instantly"| REPO
```

---

## Component Architecture

```mermaid
graph LR
    subgraph EXT["Extension Types"]
        direction TB

        SK["🔧 Skills\n/code-git-create-repo\n/code-optmz-caveman\n/code-optmz-graph\n/tools-statusline"]
        PL["🔌 Plugins\nAuto-loaded system\nextensions"]
        HK["⚡ Hooks\nEvent-driven scripts\n(startup, pre/post_commit,\ncommand, error)"]
        PM["📝 Prompts\nReusable template\nlibrary"]
        CM["💻 Commands\nCLI tools invoked\ndirectly"]
    end

    subgraph NS["Namespace Organization"]
        direction TB
        N1["code-*\nGit/GitHub/code tools"]
        N2["tools-audio-*\nAudio processing"]
        N3["tools-video-*\nVideo processing"]
        N4["tools-image-*\nImage processing"]
        N5["tools-*\nGeneral tools"]
    end

    SK --> N1
    SK --> N5
    PL --> N1
    HK --> N1
    PM --> N1
    CM --> N1
```

---

## Distribution Model

```mermaid
sequenceDiagram
    participant DEV as Developer
    participant REPO as claudifying repo
    participant INST as install.sh
    participant CLAUDE as ~/.claude/
    participant PROJ as Any Project

    DEV->>REPO: git clone
    DEV->>INST: ./install.sh
    INST->>CLAUDE: create symlinks
    Note over INST,CLAUDE: skills/ → repo/skills/<br/>plugins/ → repo/plugins/<br/>hooks/ → repo/hooks/<br/>prompts/ → repo/prompts/

    PROJ->>CLAUDE: auto-loads on startup
    DEV->>PROJ: /code-git-create-repo
    PROJ->>CLAUDE: resolves skill
    CLAUDE->>REPO: follows symlink (live source)

    Note over DEV,REPO: Update flow
    DEV->>REPO: git pull
    REPO-->>CLAUDE: symlinks already point here
    CLAUDE-->>PROJ: all projects updated instantly
```

---

## Contribution Lifecycle

```mermaid
flowchart TD
    A[Fork repo] --> B[Create feature branch]
    B --> C[Create extension directory]
    C --> D{Extension type?}

    D -->|Skill| E[skills/name/SKILL.md + impl]
    D -->|Plugin| F[plugins/name/]
    D -->|Hook| G[hooks/name/]
    D -->|Prompt| H[prompts/name/]

    E --> I[Write README + examples]
    F --> I
    G --> I
    H --> I

    I --> J[./scripts/validate.sh]
    J -->|fail| K[Fix quality issues]
    K --> J
    J -->|pass| L[Conventional commit]
    L --> M[Submit PR]
    M --> N[Maintainer review]
    N -->|approved| O[Merge to main]
    O --> P[All users get update via git pull]
```

---

## Current Extension Inventory

| Extension | Type | Namespace | Status |
|-----------|------|-----------|--------|
| `code-git-create-repo` | Skill | `code-*` | Active |
| `code-optmz-caveman` | Skill | `code-*` | Active |
| `code-optmz-graph` | Skill | `code-*` | Active |
| `tools-statusline` | Skill | `tools-*` | Active |
| `tools-audio` | Skill | `tools-audio-*` | Placeholder |
| `tools-image` | Skill | `tools-image-*` | Placeholder |
| `tools-video` | Skill | `tools-video-*` | Placeholder |

---

## Benefits

### Zero-Config Global Access
Once installed, every extension is available in **every project on the machine** — no per-project setup, no copying files, no re-configuration. Claude Code picks up `~/.claude/` automatically.

### Single Source of Truth
Symlinks point back to the git repo. One `git pull` updates all extensions everywhere simultaneously. No stale copies, no version drift across projects.

### Instant Updates, Zero Friction
```
git pull   # → every extension on machine updated
```
No re-running install. No file copying. Extensions update live because symlinks resolve at access time.

### Community-Driven Extensibility
Structured contribution workflow (fork → template → validate → PR) with:
- `CONTRIBUTING.md` — contribution guide for new contributors
- `scripts/validate.sh` — automated quality gate before review
- Conventional commits — clear, parseable history

### Namespace Isolation
Prefix-based naming (`code-*`, `tools-audio-*`, `tools-video-*`) prevents collisions and makes discovery intuitive. Categories scale without restructuring.

### Safe Installs
`install.sh` backs up existing files with timestamps before overwriting. `--dry-run` flag previews changes. `--force` opt-in for overrides. Existing symlinks handled intelligently.

### Minimal Disk Footprint
Symlinks not copies. One repo, unlimited projects. No duplication.

### Separation of Concerns
Five distinct extension types with clear contracts:
- **Skills** — user-invoked tools (`/skill-name`)
- **Plugins** — system-level auto-loaded extensions
- **Hooks** — event-driven automation (startup, commits, errors)
- **Prompts** — reusable template library
- **Commands** — direct CLI execution

Each type lives in its own directory, independently manageable.

### Reproducible Dev Environments
Clone + `./install.sh` = identical Claude Code setup on any machine. Teams share the same extension set, reducing "works on my machine" drift.
