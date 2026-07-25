#!/bin/bash

# Specify the source directory, resolved relative to this script rather than a
# hardcoded ~/.dotmez (a checkout may live elsewhere, e.g. ~/gitrepo/.dotmez)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/configs"

# Specify the destination directory
destination_dir="$HOME"

# Copy .p10k.zsh to the home directory
cp "$source_dir/.p10k.zsh" "$destination_dir"

# Copy .zshrc to the home directory
cp "$source_dir/.zshrc" "$destination_dir"

echo "Files copied successfully to $destination_dir"
