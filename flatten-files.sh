#!/bin/bash

# Check if correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_directory> <destination_directory>"
    exit 1
fi

SOURCE_DIR="$1"
DEST_DIR="$2"

# Check if source directory exists and is a Git repository
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory does not exist."
    exit 1
fi

if [ ! -d "$SOURCE_DIR/.git" ]; then
    echo "Error: Source directory is not a Git repository."
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Function to sanitize filename
sanitize_filename() {
    echo "$1" | sed -e 's/[^A-Za-z0-9._-]/-/g'
}

# Change to the source directory
cd "$SOURCE_DIR" || exit 1

# Iterate through all Git-tracked files
git ls-files | while read -r file; do
    # Get the relative path
    rel_path="$file"

    # Replace directory separators with hyphens and sanitize the filename
    new_name=$(sanitize_filename "${rel_path//\//-}")

    # Copy the file to the destination directory with the new name
    cp "$file" "$DEST_DIR/$new_name"

    echo "Copied: $rel_path -> $new_name"
done

echo "All Git-tracked files have been copied to $DEST_DIR"
