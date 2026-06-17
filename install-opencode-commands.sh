#!/usr/bin/env bash
# Installs or updates opencode commands from this dotmez repo into ~/.config/opencode/commands/

set -euo pipefail

DOTMEZ_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DOTMEZ_DIR/AI Utilities/.config/opencode/commands"
DEST="$HOME/.config/opencode/commands"

if [[ ! -d "$SRC" ]]; then
  echo "Error: opencode commands source not found at $SRC" >&2
  exit 1
fi

mkdir -p "$DEST"

# Remove old command names replaced by the task-* convention
for old_cmd in do-task add-task list-task; do
  if [[ -f "$DEST/$old_cmd.md" ]]; then
    rm -f "$DEST/$old_cmd.md"
    echo "Removed outdated command: $old_cmd"
  fi
done

for cmd_file in "$SRC"/*.md; do
  cp -v "$cmd_file" "$DEST/$(basename "$cmd_file")"
done

echo "Done — opencode commands installed to $DEST"
