#!/usr/bin/env bash
set -euo pipefail

# claudifying uninstaller
# Removes all symlinks in ~/.claude/ that point to this repo

exec "$(dirname "$0")/install.sh" --uninstall "$@"
