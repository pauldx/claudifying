#!/usr/bin/env bash
set -euo pipefail

# claudifying validation script
# Checks extensions for quality, naming, and security

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
WARNINGS=0

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

pass()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
fail()  { echo -e "${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
info()  { echo -e "${BLUE}ℹ${NC} $1"; }

# ── Check all extensions ────────────────────────────────────────

echo "Validating claudifying extensions..."
echo ""

# ── Skills ──────────────────────────────────────────────────────
echo "Checking skills..."

for skill_dir in "$REPO_DIR/skills"/*/; do
  [ ! -d "$skill_dir" ] && continue
  skill_name="$(basename "$skill_dir")"

  # Skip templates
  [[ "$skill_name" =~ ^_template ]] && continue

  # Check README
  if [ ! -f "$skill_dir/README.md" ]; then
    fail "skill: $skill_name — missing README.md"
  else
    pass "skill: $skill_name — README.md found"
  fi

  # Check metadata (SKILL.md or .skill)
  if [ ! -f "$skill_dir/SKILL.md" ] && [ ! -f "$skill_dir/${skill_name}.skill" ]; then
    warn "skill: $skill_name — missing SKILL.md or .skill file"
  fi

  # Check for hardcoded secrets (avoid false positives)
  if grep -r "api_key.*=\|secret.*=\|password.*=" "$skill_dir" --include="*.sh" --include="*.js" 2>/dev/null | grep -v "example\|template\|XXXX"; then
    fail "skill: $skill_name — contains possible hardcoded secrets"
  fi

  # Check naming convention
  if [[ ! "$skill_name" =~ ^[a-z0-9]+-[a-z0-9-]+$ ]]; then
    fail "skill: $skill_name — invalid naming (use lowercase-hyphens)"
  else
    pass "skill: $skill_name — valid naming convention"
  fi
done
echo ""

# ── Plugins ─────────────────────────────────────────────────────
echo "Checking plugins..."

for plugin_dir in "$REPO_DIR/plugins"/*/; do
  [ ! -d "$plugin_dir" ] && continue
  plugin_name="$(basename "$plugin_dir")"

  [[ "$plugin_name" =~ ^_template ]] && continue

  if [ ! -f "$plugin_dir/README.md" ]; then
    fail "plugin: $plugin_name — missing README.md"
  else
    pass "plugin: $plugin_name — README.md found"
  fi

  if [ ! -f "$plugin_dir/plugin.json" ]; then
    warn "plugin: $plugin_name — missing plugin.json manifest"
  fi
done
echo ""

# ── Hooks ───────────────────────────────────────────────────────
echo "Checking hooks..."

for hook_dir in "$REPO_DIR/hooks"/*/; do
  [ ! -d "$hook_dir" ] && continue
  hook_name="$(basename "$hook_dir")"

  [[ "$hook_name" =~ ^_template ]] && continue

  if [ ! -f "$hook_dir/README.md" ]; then
    fail "hook: $hook_name — missing README.md"
  else
    pass "hook: $hook_name — README.md found"
  fi
done
echo ""

# ── Prompts ─────────────────────────────────────────────────────
echo "Checking prompts..."

for prompt_dir in "$REPO_DIR/prompts"/*/; do
  [ ! -d "$prompt_dir" ] && continue
  prompt_name="$(basename "$prompt_dir")"

  [[ "$prompt_name" =~ ^_template ]] && continue

  if [ ! -f "$prompt_dir/README.md" ]; then
    fail "prompt: $prompt_name — missing README.md"
  else
    pass "prompt: $prompt_name — README.md found"
  fi
done
echo ""

# ── Commands ────────────────────────────────────────────────────
echo "Checking commands..."

for cmd_dir in "$REPO_DIR/commands"/*/; do
  [ ! -d "$cmd_dir" ] && continue
  cmd_name="$(basename "$cmd_dir")"

  [[ "$cmd_name" =~ ^_template ]] && continue

  if [ ! -f "$cmd_dir/README.md" ]; then
    fail "command: $cmd_name — missing README.md"
  else
    pass "command: $cmd_name — README.md found"
  fi
done
echo ""

# ── Global checks ───────────────────────────────────────────────
echo "Checking repository files..."

# Check root documentation
for file in README.md CONTRIBUTING.md LICENSE ARCHITECTURE.md INSTALL.md; do
  if [ -f "$REPO_DIR/$file" ]; then
    pass "$file exists"
  else
    fail "$file missing"
  fi
done
echo ""

# Check .gitignore
if [ -f "$REPO_DIR/.gitignore" ]; then
  # Check for common secrets in gitignore
  if grep -q "\.env" "$REPO_DIR/.gitignore"; then
    pass ".gitignore — .env excluded"
  else
    warn ".gitignore — .env not excluded"
  fi
else
  fail ".gitignore missing"
fi
echo ""

# ── Summary ─────────────────────────────────────────────────────
echo "────────────────────────────────────────────────"
echo "Validation Summary"
echo "────────────────────────────────────────────────"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "${GREEN}✓ All checks passed!${NC}"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
  echo "  Review and fix before submitting PR"
  exit 0
else
  echo -e "${RED}✗ $ERRORS error(s), $WARNINGS warning(s)${NC}"
  echo "  Must fix errors before merging"
  exit 1
fi
