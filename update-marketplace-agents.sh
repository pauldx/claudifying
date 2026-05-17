#!/bin/bash
# Auto-sync marketplace agents from upstream source
# Called by: .claude/hooks/post-merge-update-agents.sh

set -e

# Marketplace source - configure via environment variable or update this line
MARKETPLACE_REPO="${MARKETPLACE_REPO:-}"
[ -z "$MARKETPLACE_REPO" ] && { echo "❌ MARKETPLACE_REPO not set. Configure and retry."; exit 1; }
MARKETPLACE_DIR="/tmp/marketplace-agents-update"
SOURCE_AGENTS="$MARKETPLACE_DIR/.claude/agents"
LOCAL_AGENTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.claude/agents"

echo "🔄 Syncing marketplace agents..."

# Clean up old sync dir
rm -rf "$MARKETPLACE_DIR"

# Clone marketplace (shallow, no history)
git clone --depth=1 "$MARKETPLACE_REPO" "$MARKETPLACE_DIR" 2>/dev/null || {
  echo "⚠️  Failed to clone marketplace. Skipping sync."
  exit 0
}

# Sync agents from marketplace
if [ -d "$SOURCE_AGENTS" ]; then
  for agent_file in "$SOURCE_AGENTS"/*.{yml,yaml,md}; do
    [ ! -f "$agent_file" ] && continue

    agent_name=$(basename "$agent_file")
    # Convert to cf- prefix if not already
    if [[ "$agent_name" != cf-* ]]; then
      agent_name="cf-${agent_name%.*}.yml"
    fi

    local_agent="$LOCAL_AGENTS/$agent_name"

    # Copy/update agent if changed
    if [ ! -f "$local_agent" ] || ! diff -q "$agent_file" "$local_agent" >/dev/null 2>&1; then
      cp "$agent_file" "$local_agent"
    fi
  done
fi

# Clean up
rm -rf "$MARKETPLACE_DIR"

echo "✅ Marketplace agents synced"
