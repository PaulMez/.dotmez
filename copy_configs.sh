#!/bin/bash

# Specify the source directory
source_dir="$HOME/.dotmez/configs"

# Specify the destination directory
destination_dir="$HOME"

# Copy .p10k.zsh to the home directory
cp "$source_dir/.p10k.zsh" "$destination_dir"

# Copy .zshrc to the home directory
cp "$source_dir/.zshrc" "$destination_dir"

echo "Files copied successfully to $destination_dir"
