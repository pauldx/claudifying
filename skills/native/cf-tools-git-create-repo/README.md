# code-git-create-repo Skill

Automate GitHub repository creation workflow with guided steps and local setup.

## Overview

This skill streamlines new project setup by:
1. Guiding you through GitHub repo creation
2. Automating local git initialization
3. Connecting local repo to GitHub
4. Pushing initial code

## Installation

Copy to Claude Code skills:
```bash
cp code-git-create-repo.skill ~/.claude/skills/
cp -r code-git-create-repo/ ~/.claude/skills/
```

## Quick Start

### 1. Invoke Skill
```bash
/code-git-create-repo my-project
```

### 2. Follow Prompts
- Create repo on GitHub (manual step)
- Paste repo URL when done

### 3. Watch It Work
Skill automatically:
- Initializes git
- Creates .gitignore
- Creates README.md
- Makes initial commit
- Pushes to GitHub

## Usage Examples

### Basic (Public)
```bash
/code-git-create-repo my-tool
```

### Private Repository
```bash
/code-git-create-repo private-project --private
```

### With Description
```bash
/code-git-create-repo web-app --public --description "React web application"
```

### Complex Example
```bash
/code-git-create-repo data-pipeline \
  --private \
  --description "ETL data processing pipeline" \
  --author "Your Name" \
  --email "your@email.com"
```

## Workflow

### Manual Steps (GitHub)
1. Navigate to https://github.com/new
2. Enter repository name
3. Select visibility (public/private)
4. Add description (optional)
5. Click "Create repository"
6. Copy HTTPS clone URL

### Automated Steps (Local)
```
Initialize Git
├─ git init
├─ Set user email/name
├─ Create .gitignore
├─ Create README.md
├─ Stage files
└─ Initial commit

Connect to GitHub
├─ Add remote origin
├─ Rename branch to main
└─ Push to GitHub
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--public` | Public repository | true |
| `--private` | Private repository | false |
| `--description` | Repo description | None |
| `--author` | Author name | Git config |
| `--email` | Author email | Git config |
| `--branch` | Default branch | main |
| `--gitignore` | .gitignore template | Standard |

## What Gets Created

### Local
```
my-project/
├── .git/
├── .gitignore
└── README.md
```

### .gitignore (Standard)
```
node_modules/
.DS_Store
*.log
.env
dist/
build/
```

### README.md
```markdown
# my-project

Project description here.

## Getting Started

[Setup instructions]

## License

MIT
```

## Configuration

Edit `config.json` to customize:
```json
{
  "gitignore_template": "node",
  "default_license": "MIT",
  "default_branch": "main",
  "auto_push": true
}
```

## Limitations

**Cannot Do (Security):**
- ⚠️ Auto-create GitHub repos (requires auth)
- ⚠️ Auto-add collaborators
- ⚠️ Auto-configure CI/CD
- ⚠️ Auto-create deployments

**Manual Setup After:**
- GitHub repo creation
- Branch protection rules
- Collaborator invites
- Webhook configuration
- CI/CD workflows

## Troubleshooting

### "Git not found"
```bash
# Install Git
brew install git        # macOS
apt install git         # Ubuntu/Debian
choco install git       # Windows
```

### "Remote already exists"
```bash
git remote remove origin
# Re-run skill
```

### "Permission denied on push"
```bash
# Check SSH/HTTPS auth
git remote -v
# Update if needed:
git remote set-url origin https://github.com/user/repo.git
```

### ".gitignore not created"
Skill will skip if file exists. Delete to regenerate:
```bash
rm .gitignore
/code-git-create-repo --reinit
```

## Advanced Usage

### Batch Create Repos
```bash
for project in project1 project2 project3; do
  /code-git-create-repo $project --public
done
```

### Create with Custom Template
```bash
/code-git-create-repo my-project --template custom-template
```

### Create in Subdirectory
```bash
cd projects/
/code-git-create-repo sub-project
# Creates: projects/sub-project
```

## Contributing

Issues? Improvements? Submit PR:
- Fork [claudifying](https://github.com/pauldx/claudifying)
- Edit `skills/code-git-create-repo/`
- Test thoroughly
- Submit PR

See [CONTRIBUTING.md](../../CONTRIBUTING.md)

## Related Skills

- `/code-git-push` — Push existing repo
- `/code-git-commit` — Enhanced commit
- `/code-git-branch` — Branch management

## License

MIT
