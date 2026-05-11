#!/bin/bash

# code-git-create-repo: GitHub repo creation automation
# Usage: ./setup.sh <project-name> [options]
# Options: --public, --private, --description "..."

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
PROJECT_NAME="${1:-}"
VISIBILITY="public"
DESCRIPTION=""
AUTHOR="${GIT_AUTHOR_NAME:-}"
EMAIL="${GIT_AUTHOR_EMAIL:-}"

if [ -z "$PROJECT_NAME" ]; then
  echo -e "${RED}Error: Project name required${NC}"
  echo "Usage: ./setup.sh <project-name> [--public|--private] [--description \"...\"]"
  exit 1
fi

# Parse options
while [[ $# -gt 1 ]]; do
  case $2 in
    --public)
      VISIBILITY="public"
      shift
      ;;
    --private)
      VISIBILITY="private"
      shift
      ;;
    --description)
      DESCRIPTION="$3"
      shift 2
      ;;
    --author)
      AUTHOR="$3"
      shift 2
      ;;
    --email)
      EMAIL="$3"
      shift 2
      ;;
    *)
      echo -e "${YELLOW}Unknown option: $2${NC}"
      shift
      ;;
  esac
done

# Step 1: GitHub Creation (Manual)
echo ""
echo -e "${BLUE}=== STEP 1: CREATE GITHUB REPO (MANUAL) ===${NC}"
echo ""
echo "1. Go to: https://github.com/new"
echo "2. Repository name: ${YELLOW}${PROJECT_NAME}${NC}"
echo "3. Visibility: ${YELLOW}${VISIBILITY}${NC}"
if [ -n "$DESCRIPTION" ]; then
  echo "4. Description: ${YELLOW}${DESCRIPTION}${NC}"
fi
echo "5. Click 'Create repository'"
echo "6. Copy the HTTPS URL (looks like: https://github.com/username/${PROJECT_NAME}.git)"
echo ""
read -p "Paste repository URL: " REPO_URL

if [ -z "$REPO_URL" ]; then
  echo -e "${RED}Error: Repository URL required${NC}"
  exit 1
fi

# Step 2: Local Initialization
echo ""
echo -e "${BLUE}=== STEP 2: INITIALIZE LOCAL REPO ===${NC}"

# Check if directory exists
if [ -d "$PROJECT_NAME" ]; then
  cd "$PROJECT_NAME"
else
  mkdir -p "$PROJECT_NAME"
  cd "$PROJECT_NAME"
fi

# Initialize git
echo "Initializing git repository..."
git init

# Configure user if provided
if [ -n "$AUTHOR" ] && [ -n "$EMAIL" ]; then
  git config user.name "$AUTHOR"
  git config user.email "$EMAIL"
fi

# Create .gitignore
echo "Creating .gitignore..."
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
vendor/
__pycache__/
*.egg-info/

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*
yarn-debug.log*

# Build
dist/
build/
.next/
out/

# Misc
.cache
.temp
EOF

# Create README.md
echo "Creating README.md..."
cat > README.md << EOF
# ${PROJECT_NAME}

${DESCRIPTION:-Project description here.}

## Getting Started

### Prerequisites
- [Your requirements here]

### Installation
\`\`\`bash
git clone $REPO_URL
cd $PROJECT_NAME
# Setup steps
\`\`\`

### Usage
\`\`\`bash
# Usage instructions
\`\`\`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT
EOF

# Create initial commit
echo "Creating initial commit..."
git add .
git commit -m "Initial commit: ${PROJECT_NAME} setup"

# Step 3: Connect to GitHub
echo ""
echo -e "${BLUE}=== STEP 3: CONNECT TO GITHUB ===${NC}"

git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"
git branch -M main

# Push to GitHub
echo "Pushing to GitHub..."
git push -u origin main

echo ""
echo -e "${GREEN}=== SUCCESS ===${NC}"
echo ""
echo "Repository created and pushed!"
echo "URL: ${YELLOW}${REPO_URL}${NC}"
echo "Local: ${YELLOW}$(pwd)${NC}"
echo ""
echo "Next steps:"
echo "1. cd $PROJECT_NAME"
echo "2. Start developing!"
echo ""
