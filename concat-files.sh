#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 <source_directory> <output_file> [options]"
    echo "Options:"
    echo "  -g    Only include files committed to git (respects .gitignore)"
    echo "  -n    Ignore hidden files (starting with a .)"
    echo "  -i <pattern>   Ignore files or directories matching the pattern (can be used multiple times)"
    exit 1
}

# Check if correct number of arguments are provided
if [ "$#" -lt 2 ]; then
    print_usage
fi

SOURCE_DIR="$1"
OUTPUT_FILE="$2"
shift 2

# Parse options
GIT_ONLY=false
IGNORE_HIDDEN=false
IGNORE_PATTERNS=()

while getopts ":gni:" opt; do
    case ${opt} in
        g ) GIT_ONLY=true ;;
        n ) IGNORE_HIDDEN=true ;;
        i ) IGNORE_PATTERNS+=("$OPTARG") ;;
        \? ) print_usage ;;
    esac
done

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory does not exist."
    exit 1
fi

# Remove output file if it already exists
rm -f "$OUTPUT_FILE"

# Initialize variables
INCLUDED_FILES=()
TEMP_FILE=$(mktemp)
PRINTED_PATHS_FILE=$(mktemp)

# Generate list of files to include
echo "Generating list of files to include..."

# Build the find command
FIND_CMD=(find "$SOURCE_DIR" -type f)

# Exclude hidden files if -n is used
if $IGNORE_HIDDEN; then
    FIND_CMD+=( ! -name ".*" ! -path "*/.*" )
fi

# Exclude ignore patterns
for pattern in "${IGNORE_PATTERNS[@]}"; do
    FIND_CMD+=( ! -name "$pattern" ! -path "*/$pattern" )
done

# Get the list of files tracked by git if -g is used
if $GIT_ONLY; then
    GIT_FILES=$(git -C "$SOURCE_DIR" ls-files)
    # Create a temporary file for git files
    GIT_FILE_LIST=$(mktemp)
    echo "$GIT_FILES" | sed "s|^|$SOURCE_DIR/|" > "$GIT_FILE_LIST"
fi

# Function to determine if a file is text-based based on extension
is_text_file() {
    case "${1##*.}" in
        txt|md|csv|json|xml|yaml|yml|ini|cfg|conf|log|sql|sh|bash|php|js|jsx|ts|tsx|css|scss|html|htm|py|rb|go|java|c|cpp|h|hpp|swift|rs|vue)
            return 0 ;;
        *) return 1 ;;
    esac
}

# Get total number of files
echo "Counting total files..."
TOTAL_FILES=$("${FIND_CMD[@]}" | wc -l)
echo "Total files to process: $TOTAL_FILES"

# Process files
processed_files=0
included_files=0

# Use IFS to handle spaces in filenames
OLDIFS=$IFS
IFS=$'\n'

for file in `${FIND_CMD[@]}`; do
    processed_files=$((processed_files + 1))

    # Calculate and display progress
    percent=$((processed_files * 100 / TOTAL_FILES))
    echo -ne "Processing files: $processed_files/$TOTAL_FILES ($percent%)\r"

    # If -g is used, skip files not tracked by git
    if $GIT_ONLY; then
        if ! grep -Fxq "$file" "$GIT_FILE_LIST"; then
            continue
        fi
    fi

    # Check if the file should be ignored based on patterns
    should_ignore=false
    for pattern in "${IGNORE_PATTERNS[@]}"; do
        if [[ "$file" == *"$pattern"* ]]; then
            should_ignore=true
            break
        fi
    done
    $should_ignore && continue

    # Check if the file is text-based
    if is_text_file "$file"; then
        INCLUDED_FILES+=("$file")
        echo "$file" >> "$TEMP_FILE"
        included_files=$((included_files + 1))
    fi
done

IFS=$OLDIFS

skipped_files=$((TOTAL_FILES - processed_files))

echo -e "\nProcessing complete."
echo "Total files found: $TOTAL_FILES"
echo "Included files: $included_files"
echo "Skipped files: $((TOTAL_FILES - included_files))"

echo -e "\nGenerating directory structure map..."

# Generate directory structure from included files
{
    echo "root/"
    # Sort the included files for proper tree structure
    sorted_files=$(printf '%s\n' "${INCLUDED_FILES[@]}" | sort)
    for file in $sorted_files; do
        relpath="${file#$SOURCE_DIR/}"
        # Split the path into components
        IFS='/' read -ra parts <<< "$relpath"
        depth=${#parts[@]}
        path_so_far=""
        for (( i=0; i<depth; i++ )); do
            if [ -n "$path_so_far" ]; then
                path_so_far="$path_so_far/${parts[$i]}"
            else
                path_so_far="${parts[$i]}"
            fi
            # Build the indentation
            indent=""
            for (( j=0; j<i; j++ )); do
                indent+="    "
            done
            # Check if we have already printed this path
            if ! grep -Fxq "$path_so_far" "$PRINTED_PATHS_FILE"; then
                # Determine if this is a directory or file
                if [ $i -lt $((depth - 1)) ]; then
                    echo "${indent}├── ${parts[$i]}/"
                else
                    echo "${indent}└── ${parts[$i]}"
                fi
                echo "$path_so_far" >> "$PRINTED_PATHS_FILE"
            fi
        done
    done
} >> "$OUTPUT_FILE"

# Append file contents
echo -e "\n\nFile Contents:" >> "$OUTPUT_FILE"
echo "=====================" >> "$OUTPUT_FILE"

while read -r file; do
    echo "--- Content of ${file#$SOURCE_DIR/} ---" >> "$OUTPUT_FILE"
    cat "$file" >> "$OUTPUT_FILE"
    echo -e "\n\n" >> "$OUTPUT_FILE"
done < "$TEMP_FILE"

echo "All readable text files have been concatenated into $OUTPUT_FILE"

# Clean up temporary files
rm "$TEMP_FILE" "$PRINTED_PATHS_FILE"
[ -n "$GIT_FILE_LIST" ] && rm "$GIT_FILE_LIST"
