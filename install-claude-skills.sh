#!/usr/bin/env bash
# Installs or updates Claude Code skills from this dotmez repo into ~/.claude/skills/

set -euo pipefail

DOTMEZ_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DOTMEZ_DIR/AI Utilities/.claude/skills"
DEST="$HOME/.claude/skills"

if [[ ! -d "$SRC" ]]; then
  echo "Error: skills source not found at $SRC" >&2
  exit 1
fi

mkdir -p "$DEST"

for skill_dir in "$SRC"/*/; do
  skill_name="$(basename "$skill_dir")"
  dest_skill="$DEST/$skill_name"
  mkdir -p "$dest_skill"
  cp -v "$skill_dir/SKILL.md" "$dest_skill/SKILL.md"
done

echo "Done — Claude skills installed to $DEST"
