#!/usr/bin/env bash
# Install only new or changed aliases into ~/.zshrc

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_ZSHRC="$SCRIPT_DIR/configs/.zshrc"
DEST_ZSHRC="$HOME/.zshrc"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE_ZSHRC="$2"
      shift 2
      ;;
    --dest)
      DEST_ZSHRC="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--source /path/to/.zshrc] [--dest /path/to/.zshrc]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$SOURCE_ZSHRC" ]]; then
  echo "Error: source .zshrc not found at $SOURCE_ZSHRC" >&2
  exit 1
fi

alias_file="$(mktemp)"
stats_file="$(mktemp)"

awk '/^alias[[:space:]]+[A-Za-z0-9_]+=/ {
  line=$0
  name=$0
  sub(/^alias[[:space:]]+/, "", name)
  sub(/=.*/, "", name)
  print name "\t" line
}' "$SOURCE_ZSHRC" > "$alias_file"

if [[ ! -f "$DEST_ZSHRC" ]]; then
  awk -F'\t' '{print $2}' "$alias_file" > "$DEST_ZSHRC"
  added_count=$(wc -l < "$alias_file" | tr -d ' ')
  echo "Added ${added_count} alias(es). Updated 0."
  rm -f "$alias_file" "$stats_file"
  exit 0
fi

awk -v alias_file="$alias_file" -v stats_file="$stats_file" '
BEGIN {
  while ((getline < alias_file) > 0) {
    name=$1
    $1=""
    sub(/^\t/, "")
    alias_line[name]=$0
  }
  close(alias_file)
}
{
  line=$0
  if (match(line, /^alias[[:space:]]+([A-Za-z0-9_]+)=/, m)) {
    name=m[1]
    if (name in alias_line) {
      if (line != alias_line[name]) {
        line=alias_line[name]
        updated++
      }
      used[name]=1
    }
  }
  print line
}
END {
  for (name in alias_line) {
    if (!(name in used)) {
      print alias_line[name]
      added++
    }
  }
  printf("%d %d\n", added, updated) > stats_file
}
' "$DEST_ZSHRC" > "$DEST_ZSHRC.tmp"

mv "$DEST_ZSHRC.tmp" "$DEST_ZSHRC"

read -r added updated < "$stats_file"
echo "Added ${added} alias(es). Updated ${updated}."

rm -f "$alias_file" "$stats_file"
