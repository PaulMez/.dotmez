#!/bin/bash

# Install/update the herdr config.toml from this repo to ~/.config/herdr

# Resolve paths relative to this script, not a hardcoded ~/.dotmez — a working
# checkout may live anywhere (e.g. ~/gitrepo/.dotmez). Same reasoning as
# install_zellij_config.sh.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/configs/herdr"
destination_dir="$HOME/.config/herdr"

if [ ! -f "$source_dir/config.toml" ]; then
    echo "error: $source_dir/config.toml not found" >&2
    exit 1
fi

mkdir -p "$destination_dir"

# Keep a timestamped backup rather than clobbering local tweaks silently.
if [ -f "$destination_dir/config.toml" ] \
   && ! cmp -s "$source_dir/config.toml" "$destination_dir/config.toml"; then
    backup="$destination_dir/config.toml.bak.$(date +%Y%m%d%H%M%S)"
    cp "$destination_dir/config.toml" "$backup"
    echo "existing config differed; backed up to $backup"
fi

cp "$source_dir/config.toml" "$destination_dir/config.toml"

echo "herdr config installed to $destination_dir/config.toml"

# Herdr can reload without a restart, but only if a server is already running.
if command -v herdr &> /dev/null; then
    herdr server reload-config &> /dev/null \
        && echo "running herdr server reloaded" \
        || echo "note: no running herdr server to reload (fine on a fresh install)"
else
    echo "note: herdr is not on PATH yet — open a new shell after install_usuals.sh"
fi
