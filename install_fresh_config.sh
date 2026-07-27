#!/bin/bash

# Install/update the fresh config.json from this repo to ~/.config/fresh

# Resolve paths relative to this script, not a hardcoded ~/.dotmez — a working
# checkout may live anywhere (e.g. ~/gitrepo/.dotmez). Same reasoning as
# install_zellij_config.sh.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/configs/fresh"
destination_dir="$HOME/.config/fresh"

if [ ! -f "$source_dir/config.json" ]; then
    echo "error: $source_dir/config.json not found" >&2
    exit 1
fi

mkdir -p "$destination_dir"

# Keep a timestamped backup rather than clobbering local tweaks silently. Fresh
# writes this same file from its Settings UI, so a local copy that differs is
# likely to be settings you changed in-app, not stale junk.
if [ -f "$destination_dir/config.json" ] \
   && ! cmp -s "$source_dir/config.json" "$destination_dir/config.json"; then
    backup="$destination_dir/config.json.bak.$(date +%Y%m%d%H%M%S)"
    cp "$destination_dir/config.json" "$backup"
    echo "existing config differed; backed up to $backup"
fi

cp "$source_dir/config.json" "$destination_dir/config.json"

echo "fresh config installed to $destination_dir/config.json"
echo "note: Fresh reads this at startup — restart Fresh to pick it up."
