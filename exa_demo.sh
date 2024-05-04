#!/bin/bash

# Create a directory for demonstration
mkdir -p exa_demo
cd exa_demo

# Create some sample files and directories
mkdir dir1 dir2
touch file1.txt file2.txt hidden_file1.txt hidden_file2.txt
touch .dotfile1 .dotfile2
ln -s file1.txt link_to_file1

# Populate files with random data for size demonstration
echo "Hello, World!" > file1.txt
dd if=/dev/urandom of=file2.txt bs=1024 count=10 2>/dev/null
echo "This is a hidden file." > hidden_file1.txt
echo "This is another hidden file." > hidden_file2.txt

# Display various exa options
echo "Displaying files one per line:"
exa -1

echo "Displaying files in grid (default):"
exa -G

echo "Displaying extended details:"
exa -l

echo "Recursing into directories:"
exa -R

echo "Displaying directories as a tree:"
exa -T

echo "Sorting the grid across:"
exa -x

echo "Displaying type indicators by file names:"
exa -F

echo "Using colors:"
exa --colour=always

echo "Using colour scale for file sizes:"
exa --colour-scale

echo "Displaying icons:"
exa --icons

echo "Displaying all files, including hidden:"
exa -a

echo "Listing directories like regular files:"
exa -d

echo "Limiting recursion depth to 1:"
exa -L 1

echo "Reversing sort order:"
exa -r

echo "Sorting by file size:"
exa -s=size

echo "Listing only directories:"
exa -D

echo "Ignoring files as per .gitignore:"
exa --git-ignore

echo "Ignoring files matching glob patterns:"
exa -I '*.txt'

# Return to original directory and clean up if necessary
cd ..
echo "Demo complete. You can delete the 'exa_demo' directory if not needed."
