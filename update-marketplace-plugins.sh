#!/bin/bash
# Auto-sync marketplace plugins from upstream source
# Called by: .claude/hooks/post-merge-update-plugins.sh

set -e

# Marketplace source - configure via environment variable or update this line
MARKETPLACE_REPO="${MARKETPLACE_REPO:-}"
[ -z "$MARKETPLACE_REPO" ] && { echo "❌ MARKETPLACE_REPO not set. Configure and retry."; exit 1; }
MARKETPLACE_DIR="/tmp/marketplace-plugins-update"
SOURCE_PLUGINS="$MARKETPLACE_DIR/plugins"
LOCAL_PLUGINS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/plugins"

echo "🔄 Syncing marketplace plugins..."

# Clean up old sync dir
rm -rf "$MARKETPLACE_DIR"

# Clone marketplace (shallow, no history)
git clone --depth=1 "$MARKETPLACE_REPO" "$MARKETPLACE_DIR" 2>/dev/null || {
  echo "⚠️  Failed to clone marketplace. Skipping sync."
  exit 0
}

# Sync each category
for category_dir in "$SOURCE_PLUGINS"/{ai-agency,ai-ml,api-development,business-tools,community,crypto,database,design,devops,examples,mcp,packages,performance,productivity,saas-packs,security,skill-enhancers,testing}; do
  [ ! -d "$category_dir" ] && continue

  category_name=$(basename "$category_dir")
  local_cat="$LOCAL_PLUGINS/$category_name"
  mkdir -p "$local_cat"

  # Sync plugins in this category
  for plugin_dir in "$category_dir"*/; do
    [ ! -d "$plugin_dir" ] && continue

    plugin_name=$(basename "$plugin_dir")
    local_plugin="$local_cat/$plugin_name"

    # Copy/update plugin if changed
    if [ -f "$plugin_dir/.claude-plugin" ] || [ -f "$plugin_dir/package.json" ]; then
      if [ ! -d "$local_plugin" ] || ! diff -q "$plugin_dir/.claude-plugin" "$local_plugin/.claude-plugin" >/dev/null 2>&1; then
        mkdir -p "$local_plugin"
        cp -r "$plugin_dir"/* "$local_plugin/" 2>/dev/null || true
      fi
    fi
  done
done

# Clean up
rm -rf "$MARKETPLACE_DIR"

echo "✅ Marketplace plugins synced"
