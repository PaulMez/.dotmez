#!/bin/bash

# Specify the source directory
source_dir="$HOME"

# Specify the files to back up
files=("~/.p10k.zsh" "~/.zshrc")

# Specify the backup directory
backup_dir="$HOME/.dotmez/configs"

# Create backup directory if it doesn't exist
mkdir -p "$backup_dir"

# Loop through each file and create a backup with timestamp
for file in "${files[@]}"; do
    filename=$(basename "$file")
    timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_filename="${filename%.*}_backup_$timestamp.${filename##*.}"
    cp "$source_dir/$filename" "$backup_dir/$backup_filename"
    echo "Backup created: $backup_dir/$backup_filename"
done
