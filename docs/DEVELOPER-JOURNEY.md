# Developer Journey with Claudifying

Visual guides for using Claudifying at different stages of your development workflow.

## 1. Developer Personas & Scenarios

```mermaid
flowchart TB
    subgraph PERSONAS["Developer Personas"]
        direction LR
        NEW["New Developer<br/>(just joined team)"]
        EXISTING["Existing Developer<br/>(already has toolkit)"]
        CONTRIBUTOR["Contributor<br/>(adding new skill/command)"]
    end

    subgraph SCENARIOS["Project Scenarios"]
        direction LR
        NEWREPO["New Repo<br/>(fresh project)"]
        OLDREPO["Legacy Repo<br/>(no .claude/ folder)"]
        SETUPREPO["Configured Repo<br/>(has .claude/ setup)"]
    end

    NEW --> ONBOARD["One-Time Setup<br/>(2 minutes)"]
    EXISTING --> DAILY["Daily Work"]
    CONTRIBUTOR --> CONTRIBUTE["Add & Share"]

    ONBOARD --> DAILY
    CONTRIBUTE --> DAILY

    DAILY --> NEWREPO
    DAILY --> OLDREPO
    DAILY --> SETUPREPO

    NEWREPO --> WORKS["All skills work<br/>(Global)"]
    OLDREPO --> WORKS
    SETUPREPO --> WORKS_PLUS["Skills + Agents<br/>(Global + Project)"]

    style NEW fill:#E3F2FD,stroke:#1976D2
    style EXISTING fill:#E8F5E9,stroke:#4CAF50
    style CONTRIBUTOR fill:#FFF3E0,stroke:#FF9800
    style WORKS fill:#E8F5E9,stroke:#4CAF50
    style WORKS_PLUS fill:#F3E5F5,stroke:#9C27B0
```

## 2. New Developer Onboarding

```mermaid
flowchart LR
    subgraph DAY1["Day 1: Setup"]
        direction TB
        JOIN["Join team"] --> CLONE["git clone claudifying<br/>~/claudifying"]
        CLONE --> INSTALL["./install.sh --force"]
        INSTALL --> VERIFY["Verify: ls ~/.claude/skills/"]
    end

    subgraph RESULT["What You Get"]
        direction TB
        SKL["13 Skills<br/>/cf-code-review<br/>/cf-refactor<br/>..."]
        CMD["5 Commands<br/>/cf-bootstrap<br/>/cf-document<br/>..."]
        AGENTS["4 Agents<br/>code-reviewer<br/>security-auditor<br/>..."]
    end

    subgraph READY["Ready to Work"]
        direction TB
        ANY["Open ANY repo"] --> USE["All tools available"]
    end

    DAY1 --> RESULT
    RESULT --> READY

    style DAY1 fill:#E3F2FD,stroke:#1976D2
    style RESULT fill:#E8F5E9,stroke:#4CAF50
    style READY fill:#F3E5F5,stroke:#9C27B0
```

## 3. Daily Workflow: Which Layer Applies?

```mermaid
flowchart TB
    DEV["Developer opens<br/>Claude Code"]
    
    DEV --> CHECK{"What kind<br/>of repo?"}
    
    CHECK -->|"Any repo<br/>(even empty)"| L1["Layer 1: Global<br/>~/.claude/"]
    CHECK -->|"Repo with<br/>.claude/settings.json"| L1L2["Layer 1 + Layer 2<br/>Global + Project"]

    subgraph LAYER1["Layer 1: Always Available"]
        direction LR
        C1["13 Skills"]
        S1["5 Commands"]
        R1["2 Rules"]
    end

    subgraph LAYER2["Layer 2: Per-Project"]
        direction LR
        A2["4 Agents"]
        H2["4 Hooks"]
    end

    L1 --> LAYER1
    L1L2 --> LAYER1
    L1L2 --> LAYER2

    style L1 fill:#E8F5E9,stroke:#4CAF50
    style L1L2 fill:#FFF3E0,stroke:#FF9800
    style LAYER1 fill:#E8F5E9,stroke:#4CAF50
    style LAYER2 fill:#FFF3E0,stroke:#FF9800
```

## 4. Project Setup Decision Tree

```mermaid
flowchart TB
    START["You open a project<br/>in Claude Code"]
    
    START --> Q1{"Need agents<br/>or hooks?"}
    
    Q1 -->|"No, skills<br/>are enough"| DONE1["You're done!<br/>Layer 1 covers you"]
    
    Q1 -->|"Yes"| Q2{"Project already<br/>has .claude/?"}
    
    Q2 -->|"No"| SETUP["/cf-bootstrap agent<br/>(creates .claude/)"]
    Q2 -->|"Yes, configured"| DONE2["You're done!<br/>Agents available"]
    
    SETUP --> COMMIT["git add .claude/<br/>git commit"]
    COMMIT --> SHARE["Teammates get it<br/>on git pull"]
    SHARE --> DONE2

    style DONE1 fill:#E8F5E9,stroke:#4CAF50
    style DONE2 fill:#F3E5F5,stroke:#9C27B0
    style SETUP fill:#FFF3E0,stroke:#FF9800
```

## 5. Contribution & Update Cycle

```mermaid
flowchart TB
    subgraph CONTRIBUTE["Anyone Can Contribute"]
        direction TB
        IDEA["Have idea for<br/>new skill/command"] --> CREATE["Create .md file<br/>in claudifying"]
        CREATE --> TEST["./install.sh<br/>Test locally"]
        TEST --> PR["git push<br/>Create PR"]
        PR --> MERGE["PR merged<br/>to main"]
    end

    subgraph DISTRIBUTE["Everyone Gets Updates"]
        direction TB
        PULL["cd ~/claudifying<br/>git pull"]
        PULL --> AUTO{"New files<br/>added?"}
        AUTO -->|"No"| INSTANT["Symlinks update<br/>instantly"]
        AUTO -->|"Yes"| REINSTALL["./install.sh<br/>(create new symlinks)"]
        REINSTALL --> INSTANT
    end

    subgraph TEAM["Team of N Developers"]
        direction LR
        D1["Dev 1"]
        D2["Dev 2"]
        D3["Dev 3"]
        DN["Dev N..."]
    end

    MERGE --> NOTIFY["Announce: new skill available"]
    NOTIFY --> TEAM
    TEAM --> PULL

    style CONTRIBUTE fill:#E3F2FD,stroke:#1976D2
    style DISTRIBUTE fill:#E8F5E9,stroke:#4CAF50
    style TEAM fill:#FFF3E0,stroke:#FF9800
```

## 6. Complete System Overview

```mermaid
flowchart TB
    subgraph GITHUB["GitHub: claudifying"]
        direction LR
        SRC["Source<br/>13 skills, 5 commands, 2 rules<br/>4 agents, 4 hooks"]
    end

    subgraph TEAM["Your Team"]
        direction TB
        
        subgraph NEW_DEV["New Developer"]
            N1["Clone repo"] --> N2["./install.sh"]
        end
        
        subgraph EXISTING_DEV["Existing Developers"]
            E1["git pull"] --> E2["Symlinks auto-update"]
        end
        
        subgraph CONTRIBUTOR_DEV["Contributor"]
            C1["Add skill"] --> C2["PR"] --> C3["Merge"]
        end
    end

    subgraph MACHINE["Each Developer's Machine"]
        direction TB
        
        subgraph GLOBAL["~/.claude/ (Global)"]
            G1["skills/ -> symlinks"]
            G2["commands/ -> symlinks"]
            G3["rules/ -> symlinks"]
        end
        
        subgraph PROJECT["<project>/.claude/ (Per-Project)"]
            P1["agents/ -> symlink"]
            P2["settings.json"]
        end
    end

    subgraph REPOS["Any Repository"]
        direction LR
        R1["Old repo<br/>(no .claude)"]
        R2["New repo<br/>(fresh)"]
        R3["Configured repo<br/>(.claude exists)"]
    end

    subgraph CLAUDE["Claude Code Session"]
        direction TB
        LOAD["Load global + project config"]
        WORK["All extensions available"]
        LOAD --> WORK
    end

    GITHUB --> TEAM
    NEW_DEV --> GLOBAL
    EXISTING_DEV --> GLOBAL
    CONTRIBUTOR_DEV --> GITHUB
    
    GLOBAL --> CLAUDE
    PROJECT -.-> CLAUDE
    
    REPOS --> CLAUDE

    style GITHUB fill:#24292e,stroke:#24292e,color:#fff
    style NEW_DEV fill:#E3F2FD,stroke:#1976D2
    style EXISTING_DEV fill:#E8F5E9,stroke:#4CAF50
    style CONTRIBUTOR_DEV fill:#FFF3E0,stroke:#FF9800
    style GLOBAL fill:#E8F5E9,stroke:#4CAF50
    style PROJECT fill:#FFF3E0,stroke:#FF9800
    style CLAUDE fill:#F3E5F5,stroke:#9C27B0
```

## 7. What Do I Need? Decision Matrix

```mermaid
flowchart LR
    subgraph NEED["What I Need"]
        direction TB
        N1["Just skills<br/>(/cf-code-review, /cf-refactor)"]
        N2["Skills + Agents<br/>(code-reviewer, security-auditor)"]
    end

    subgraph DO["What I Do"]
        direction TB
        D1["./install.sh<br/>(one time)"]
        D2["./install.sh +<br/>.claude/ setup"]
    end

    subgraph GET["What I Get"]
        direction TB
        G1["Layer 1<br/>Global everywhere"]
        G2["Layer 1 + 2<br/>Global + Project agents"]
    end

    N1 --> D1 --> G1
    N2 --> D2 --> G2

    style N1 fill:#E8F5E9,stroke:#4CAF50
    style N2 fill:#FFF3E0,stroke:#FF9800
    style G1 fill:#E8F5E9,stroke:#4CAF50
    style G2 fill:#FFF3E0,stroke:#FF9800
```

---

**Want to contribute?** See the decision tree above + [README.md](../README.md) for the contribution workflow.

**Questions?** Check [DAILY-PRACTICES.md](./DAILY-PRACTICES.md) for tips + tricks, or [AGENT-TEAMS.md](./AGENT-TEAMS.md) for parallel development patterns.
