#!/bin/bash
# Auto-sync marketplace skills from upstream source
# Called by: .claude/hooks/post-merge-update-skills.sh

set -e

# Marketplace source - configure via environment variable or update this line
MARKETPLACE_REPO="${MARKETPLACE_REPO:-}"
[ -z "$MARKETPLACE_REPO" ] && { echo "❌ MARKETPLACE_REPO not set. Configure and retry."; exit 1; }
MARKETPLACE_DIR="/tmp/marketplace-skills-sync"
SOURCE_SKILLS="$MARKETPLACE_DIR/skills"
LOCAL_SKILLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skills"

echo "🔄 Syncing marketplace skills..."

# Clean up old sync dir
rm -rf "$MARKETPLACE_DIR"

# Clone marketplace (shallow, no history)
git clone --depth=1 "$MARKETPLACE_REPO" "$MARKETPLACE_DIR" 2>/dev/null || {
  echo "⚠️  Failed to clone marketplace. Skipping sync."
  exit 0
}

# Sync each category (01-20)
for cat_dir in "$SOURCE_SKILLS"/{01..20}-*/; do
  cat_name=$(basename "$cat_dir")
  local_cat="$LOCAL_SKILLS/$cat_name"

  # Create category folder if missing
  mkdir -p "$local_cat"

  # Sync skills in this category
  for skill_dir in "$cat_dir"*/; do
    skill_name=$(basename "$skill_dir")
    skill_cf_name="cf-$(echo "$skill_name" | tr '_' '-')"
    local_skill="$local_cat/$skill_cf_name"

    # Copy/update skill if changed
    if [ -f "$skill_dir/SKILL.md" ]; then
      if [ ! -d "$local_skill" ] || ! diff -q "$skill_dir/SKILL.md" "$local_skill/SKILL.md" >/dev/null 2>&1; then
        mkdir -p "$local_skill"
        cp -r "$skill_dir"/* "$local_skill/" 2>/dev/null || true
      fi
    fi
  done
done

# Clean up
rm -rf "$MARKETPLACE_DIR"

echo "✅ Marketplace skills synced"
