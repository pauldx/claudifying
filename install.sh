#!/usr/bin/env bash
set -euo pipefail

# claudifying installer
# Symlinks skills, plugins, hooks, and prompts into ~/.claude/ (global scope)
# so they are available in ALL repos — not just this one.
#
# Usage: ./install.sh [--dry-run] [--force] [--uninstall]

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/pre-claudifying-install-$(date +%Y%m%d-%H%M%S)"

DRY_RUN=false
UNINSTALL=false
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --uninstall) UNINSTALL=true ;;
    --force) FORCE=true ;;
    --help|-h)
      echo "Usage: ./install.sh [--dry-run] [--force] [--uninstall]"
      echo ""
      echo "  --dry-run    Preview changes without making them"
      echo "  --force      Replace existing files (backs up originals first)"
      echo "  --uninstall  Remove all symlinks pointing to this repo"
      echo ""
      echo "Installs into ~/.claude/ (global scope) so everything works in ALL repos:"
      echo "  Skills   → ~/.claude/skills/      (tools: /skill-name)"
      echo "  Agents   → ~/.claude/agents/      (specialized subagents)"
      echo "  Commands → ~/.claude/commands/    (slash commands: /command-name)"
      echo "  Rules    → ~/.claude/rules/       (conditional guidance)"
      echo "  Plugins  → ~/.claude/plugins/     (system extensions)"
      echo "  Hooks    → ~/.claude/hooks/       (event-driven automation)"
      echo "  Prompts  → ~/.claude/prompts/     (reusable templates)"
      echo ""
      exit 0
      ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ── Helpers: symlink directories and files ─────────────────────
backup_created=false
total_linked=0
total_skipped=0
total_backed_up=0

symlink_dir() {
  local src="$1"
  local dest="$2"
  local label="$3"

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ]; then
      local existing="$(readlink "$dest")"
      if [[ "$existing" == "$REPO_DIR"* ]]; then
        [ "$DRY_RUN" = true ] && { info "[dry-run] Would update: $label"; total_linked=$((total_linked + 1)); return; }
        rm "$dest"; ln -s "$src" "$dest"
        success "Updated: $label"
        total_linked=$((total_linked + 1)); return
      fi
    fi
    if [ "$FORCE" = true ]; then
      [ "$DRY_RUN" = true ] && { info "[dry-run] Would replace: $label"; total_linked=$((total_linked + 1)); return; }
      [ "$backup_created" = false ] && { mkdir -p "$BACKUP_DIR"; backup_created=true; }
      if [ -L "$dest" ]; then cp -P "$dest" "$BACKUP_DIR/"; else cp -rP "$dest" "$BACKUP_DIR/"; fi
      rm -rf "$dest"; ln -s "$src" "$dest"
      success "Replaced: $label — original backed up"
      total_linked=$((total_linked + 1)); total_backed_up=$((total_backed_up + 1)); return
    else
      warn "Skipped: $label — already exists (use --force)"
      total_skipped=$((total_skipped + 1)); return
    fi
  fi

  [ "$DRY_RUN" = true ] && { info "[dry-run] Would link: $label"; total_linked=$((total_linked + 1)); return; }
  ln -s "$src" "$dest"
  success "Linked: $label"
  total_linked=$((total_linked + 1))
}

symlink_file() {
  symlink_dir "$@"  # Files and dirs use same logic for symlinks
}

# ── Uninstall mode ──────────────────────────────────────────────
if [ "$UNINSTALL" = true ]; then
  info "Removing all symlinks pointing to: $REPO_DIR"
  removed=0

  # Skills
  for link in "$CLAUDE_DIR/skills"/*/; do
    link="${link%/}"
    [ -L "$link" ] || continue
    [[ "$(readlink "$link")" == "$REPO_DIR"* ]] || continue
    [ "$DRY_RUN" = true ] && { info "[dry-run] Would remove skill: $(basename "$link")"; removed=$((removed + 1)); continue; }
    rm "$link"; success "Removed skill: $(basename "$link")"; removed=$((removed + 1))
  done

  # Agents
  for link in "$CLAUDE_DIR/agents"/*; do
    [ -L "$link" ] || continue
    [[ "$(readlink "$link")" == "$REPO_DIR"* ]] || continue
    [ "$DRY_RUN" = true ] && { info "[dry-run] Would remove agent: $(basename "$link")"; removed=$((removed + 1)); continue; }
    rm "$link"; success "Removed agent: $(basename "$link")"; removed=$((removed + 1))
  done

  # Commands
  for link in "$CLAUDE_DIR/commands"/*/*; do
    [ -L "$link" ] || continue
    [[ "$(readlink "$link")" == "$REPO_DIR"* ]] || continue
    [ "$DRY_RUN" = true ] && { info "[dry-run] Would remove command: $(basename "$link")"; removed=$((removed + 1)); continue; }
    rm "$link"; success "Removed command: $(basename "$link")"; removed=$((removed + 1))
  done

  # Rules
  for link in "$CLAUDE_DIR/rules"/*; do
    [ -L "$link" ] || continue
    [[ "$(readlink "$link")" == "$REPO_DIR"* ]] || continue
    [ "$DRY_RUN" = true ] && { info "[dry-run] Would remove rule: $(basename "$link")"; removed=$((removed + 1)); continue; }
    rm "$link"; success "Removed rule: $(basename "$link")"; removed=$((removed + 1))
  done

  # Plugins
  for link in "$CLAUDE_DIR/plugins"/*/; do
    link="${link%/}"
    [ -L "$link" ] || continue
    [[ "$(readlink "$link")" == "$REPO_DIR"* ]] || continue
    [ "$DRY_RUN" = true ] && { info "[dry-run] Would remove plugin: $(basename "$link")"; removed=$((removed + 1)); continue; }
    rm "$link"; success "Removed plugin: $(basename "$link")"; removed=$((removed + 1))
  done

  # Hooks
  for link in "$CLAUDE_DIR/hooks"/*; do
    [ -L "$link" ] || continue
    [[ "$(readlink "$link")" == "$REPO_DIR"* ]] || continue
    [ "$DRY_RUN" = true ] && { info "[dry-run] Would remove hook: $(basename "$link")"; removed=$((removed + 1)); continue; }
    rm "$link"; success "Removed hook: $(basename "$link")"; removed=$((removed + 1))
  done

  # Prompts
  for link in "$CLAUDE_DIR/prompts"/*/; do
    link="${link%/}"
    [ -L "$link" ] || continue
    [[ "$(readlink "$link")" == "$REPO_DIR"* ]] || continue
    [ "$DRY_RUN" = true ] && { info "[dry-run] Would remove prompt: $(basename "$link")"; removed=$((removed + 1)); continue; }
    rm "$link"; success "Removed prompt: $(basename "$link")"; removed=$((removed + 1))
  done

  [ "$removed" -eq 0 ] && info "No symlinks from this repo found." || success "Removed $removed symlink(s)."
  exit 0
fi

# ── Install mode ────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   claudifying installer                      ║"
echo "║   Installs globally → works in ALL repos     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

if [ ! -d "$CLAUDE_DIR" ]; then
  error "~/.claude/ does not exist. Install Claude Code first."
  exit 1
fi

# Ensure target directories exist
for dir in "$CLAUDE_DIR/skills" "$CLAUDE_DIR/plugins" "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/prompts" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/rules"; do
  [ -d "$dir" ] || { [ "$DRY_RUN" = false ] && mkdir -p "$dir"; }
done

# ── 1. Skills ───────────────────────────────────────────────────
echo -e "${BOLD}Skills${NC} → ~/.claude/skills/"

skill_count=0
# Link skills from both ./skills/ and ./.claude/skills/
for skill_dir in "$REPO_DIR/skills"/*/ "$REPO_DIR/.claude/skills"/*/; do
  [ ! -d "$skill_dir" ] && continue
  skill_name="$(basename "$skill_dir")"
  [ "$skill_name" = "_template" ] && continue
  symlink_dir "$skill_dir" "$CLAUDE_DIR/skills/$skill_name" "skill: /$skill_name"
  skill_count=$((skill_count + 1))
done
echo ""

# ── 2. Plugins ──────────────────────────────────────────────────
echo -e "${BOLD}Plugins${NC} → ~/.claude/plugins/"

plugin_count=0
for plugin_dir in "$REPO_DIR/plugins"/*/; do
  [ ! -d "$plugin_dir" ] && continue
  plugin_name="$(basename "$plugin_dir")"
  [ "$plugin_name" = "_template" ] && continue
  symlink_dir "$plugin_dir" "$CLAUDE_DIR/plugins/$plugin_name" "plugin: $plugin_name"
  plugin_count=$((plugin_count + 1))
done
echo ""

# ── 3. Hooks ────────────────────────────────────────────────────
echo -e "${BOLD}Hooks${NC} → ~/.claude/hooks/"

hook_count=0
for hook_file in "$REPO_DIR/.claude/hooks"/*.sh; do
  [ ! -f "$hook_file" ] && continue
  hook_name="$(basename "$hook_file")"
  symlink_file "$hook_file" "$CLAUDE_DIR/hooks/$hook_name" "hook: $hook_name"
  hook_count=$((hook_count + 1))
done

# Configure git to use hooks from .claude/hooks
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" config core.hooksPath .claude/hooks
  info "Git hooks configured at: .claude/hooks/"
fi
echo ""

# ── 4. Prompts ──────────────────────────────────────────────────
echo -e "${BOLD}Prompts${NC} → ~/.claude/prompts/"

prompt_count=0
for prompt_dir in "$REPO_DIR/prompts"/*/; do
  [ ! -d "$prompt_dir" ] && continue
  prompt_name="$(basename "$prompt_dir")"
  [ "$prompt_name" = "_template" ] && continue
  symlink_dir "$prompt_dir" "$CLAUDE_DIR/prompts/$prompt_name" "prompt: $prompt_name"
  prompt_count=$((prompt_count + 1))
done
echo ""

# ── 5. Agents ────────────────────────────────────────────────────
echo -e "${BOLD}Agents${NC} → ~/.claude/agents/"

agent_count=0
for agent_file in "$REPO_DIR/.claude/agents"/*.yml; do
  [ ! -f "$agent_file" ] && continue
  agent_name="$(basename "$agent_file")"
  [ "$agent_name" = "_template.yml" ] && continue
  symlink_file "$agent_file" "$CLAUDE_DIR/agents/$agent_name" "agent: $agent_name"
  agent_count=$((agent_count + 1))
done
echo ""

# ── 6. Commands ──────────────────────────────────────────────────
echo -e "${BOLD}Commands${NC} → ~/.claude/commands/"

command_count=0
for cmd_file in "$REPO_DIR/.claude/commands"/**/*.md; do
  [ ! -f "$cmd_file" ] && continue
  cmd_name="$(basename "$cmd_file" .md)"
  [ "$cmd_name" = "_template" ] && continue
  cmd_dir="$(dirname "$cmd_file" | xargs basename)"
  mkdir -p "$CLAUDE_DIR/commands/$cmd_dir"
  symlink_file "$cmd_file" "$CLAUDE_DIR/commands/$cmd_dir/$cmd_name.md" "command: /$cmd_name"
  command_count=$((command_count + 1))
done
echo ""

# ── 7. Rules ─────────────────────────────────────────────────────
echo -e "${BOLD}Rules${NC} → ~/.claude/rules/"

rule_count=0
for rule_file in "$REPO_DIR/.claude/rules"/*.md; do
  [ ! -f "$rule_file" ] && continue
  rule_name="$(basename "$rule_file")"
  symlink_file "$rule_file" "$CLAUDE_DIR/rules/$rule_name" "rule: $rule_name"
  rule_count=$((rule_count + 1))
done
echo ""

# ── Summary ─────────────────────────────────────────────────────
echo "────────────────────────────────────────────────"
echo "  Summary"
echo "────────────────────────────────────────────────"
echo "  Skills:    $skill_count found"
echo "  Agents:    $agent_count found"
echo "  Commands:  $command_count found"
echo "  Rules:     $rule_count found"
echo "  Plugins:   $plugin_count found"
echo "  Hooks:     $hook_count found"
echo "  Prompts:   $prompt_count found"
echo "  Linked:    $total_linked"
echo "  Skipped:   $total_skipped (conflicts)"
[ "$total_backed_up" -gt 0 ] && echo "  Backups:   $BACKUP_DIR"
echo ""

# ── Usage note ──────────────────────────────────────────────────
info "Installation complete!"
echo "  Skills:    /skill-name (e.g., /code-review, /refactor)"
echo "  Commands:  /command-name (e.g., /bootstrap, /test-all)"
echo "  Agents:    Specialized subagents for code-review, devops, security, testing"
echo "  Hooks:     Automate on events (pre-commit secrets, post-tool format, etc.)"
echo "  Rules:     Conditional guidance for git workflow, command authoring"
echo "  Plugins:   Extend Claude Code functionality"
echo "  Prompts:   Reusable prompt templates"
echo ""

# ── Auto-update tip ─────────────────────────────────────────────
info "To get updates: cd $REPO_DIR && git pull"
echo "  Symlinked content updates instantly — no re-install needed."
echo "  Re-run ./install.sh only when NEW skills/plugins/hooks/prompts are added."
echo ""

[ "$DRY_RUN" = true ] && info "Dry run complete. No changes were made."

success "Done! All extensions are available in ALL your repos."
echo ""
