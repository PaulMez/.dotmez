#!/bin/bash

# Install/update the zellij config.kdl from this repo to ~/.config/zellij

# Resolve paths relative to this script, not a hardcoded ~/.dotmez. On a fresh
# machine install_usuals.sh clones to ~/.dotmez, but a working checkout may live
# anywhere (e.g. ~/gitrepo/.dotmez) — hardcoding made this script silently copy
# from a stale clone, or fail outright.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/configs/zellij"
destination_dir="$HOME/.config/zellij"

if [ ! -f "$source_dir/config.kdl" ]; then
    echo "error: $source_dir/config.kdl not found" >&2
    exit 1
fi

mkdir -p "$destination_dir"

# Keep a timestamped backup rather than clobbering local tweaks silently.
if [ -f "$destination_dir/config.kdl" ] \
   && ! cmp -s "$source_dir/config.kdl" "$destination_dir/config.kdl"; then
    backup="$destination_dir/config.kdl.bak.$(date +%Y%m%d%H%M%S)"
    cp "$destination_dir/config.kdl" "$backup"
    echo "existing config differed; backed up to $backup"
fi

cp "$source_dir/config.kdl" "$destination_dir/config.kdl"

echo "zellij config installed to $destination_dir/config.kdl"
echo "note: default_mode \"locked\" applies to NEW sessions only — restart zellij."
