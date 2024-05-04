#!/bin/bash

# Specify the source directory
source_dir="$HOME"

# Specify the files to back up
files=("~/.p10k.zsh" "~/.zshrc")

# Specify the backup directory
backup_dir="$HOME/.dotmez/configs"

# Create backup directory if it doesn't exist
mkdir -p "$backup_dir"

# Loop through each file, check if it exists, and create a backup with timestamp
for file in "${files[@]}"; do
    filename=$(basename "$file")
    if [ -e "$source_dir/$filename" ]; then
        timestamp=$(date +"%Y%m%d_%H%M%S")
        backup_filename="${filename%.*}_backup_$timestamp.${filename##*.}"
        cp "$source_dir/$filename" "$backup_dir/$backup_filename"
        echo "Backup created: $backup_dir/$backup_filename"
    else
        echo "File does not exist: $source_dir/$filename"
    fi
done
