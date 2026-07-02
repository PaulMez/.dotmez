#!/bin/bash

# Install/update the zellij config.kdl from this repo to ~/.config/zellij

source_dir="$HOME/.dotmez/configs/zellij"
destination_dir="$HOME/.config/zellij"

mkdir -p "$destination_dir"
cp "$source_dir/config.kdl" "$destination_dir/config.kdl"

echo "zellij config installed to $destination_dir/config.kdl"
