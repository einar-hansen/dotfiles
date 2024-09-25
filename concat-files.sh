#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 <source_directory> <output_file> [options]"
    echo "Options:"
    echo "  -g    Only include files committed to git (respects .gitignore)"
    echo "  -d    Only include files available to docker (respects .dockerignore)"
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
DOCKER_ONLY=false
IGNORE_HIDDEN=false
declare -a IGNORE_PATTERNS

while getopts ":gdni:" opt; do
    case ${opt} in
        g ) GIT_ONLY=true ;;
        d ) DOCKER_ONLY=true ;;
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

# Function to check if a file is likely to be text
is_text_file() {
    local mime_type
    mime_type=$(file --mime-type "$1" | awk '{print $NF}')
    case "$mime_type" in
        text/*|application/json|application/xml|application/x-php|application/javascript)
            return 0
            ;;
    esac
    # Check file extension for common text-based formats
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        *.txt|*.md|*.csv|*.json|*.xml|*.yaml|*.yml|*.ini|*.cfg|*.conf|*.log|*.sql|*.sh|*.bash|*.php|*.js|*.css|*.html|*.htm)
            return 0
            ;;
    esac
    return 1
}

# Function to check if a file should be ignored based on the ignore patterns
should_ignore_file() {
    local file="$1"
    for pattern in "${IGNORE_PATTERNS[@]}"; do
        if [[ "$file" == *"$pattern"* ]]; then
            return 0
        fi
    done
    return 1
}

# Function to check if a file should be included based on options
should_include_file() {
    local file="$1"
    # Check if file should be ignored
    if [ ${#IGNORE_PATTERNS[@]} -ne 0 ] && should_ignore_file "$file"; then
        return 1
    fi
    # Check for hidden files
    if $IGNORE_HIDDEN && [[ $(basename "$file") == .* ]]; then
        return 1
    fi
    # Check for git-committed files
    if $GIT_ONLY; then
        if ! git ls-files --error-unmatch "$file" &> /dev/null; then
            return 1
        fi
    fi
    # Check for docker-available files
    if $DOCKER_ONLY; then
        if docker build -f - . -t temp_image <<< "FROM scratch
COPY $file /tmp/" &> /dev/null; then
            docker rmi temp_image &> /dev/null
        else
            return 1
        fi
    fi
    return 0
}

# Create a temporary file to store included files
TEMP_FILE=$(mktemp)

# Count total files
total_files=$(find "$SOURCE_DIR" -type f | wc -l)

echo "Starting file processing..."

# Use a subshell to process files and update the counter in real-time
(
    processed_files=0
    while read -r file; do
        ((processed_files++))
        echo -ne "Processing files: $processed_files/$total_files\r"
        if should_include_file "$file" && is_text_file "$file"; then
            echo "--- Content of $file ---" >> "$OUTPUT_FILE"
            cat "$file" >> "$OUTPUT_FILE"
            echo -e "\n\n" >> "$OUTPUT_FILE"
            echo "$file" >> "$TEMP_FILE"
        fi
    done < <(find "$SOURCE_DIR" -type f)
)

# Count the number of included files
included_files=$(wc -l < "$TEMP_FILE")
processed_files=$total_files
skipped_files=$((total_files - included_files))

echo -e "\nProcessing complete."
echo "Total files: $total_files"
echo "Processed files: $processed_files"
echo "Skipped files: $skipped_files"
echo "Included files: $included_files"

echo -e "\nList of included files:"
cat "$TEMP_FILE"

echo -e "\nAll readable text files have been concatenated into $OUTPUT_FILE"

# Clean up temporary file
rm "$TEMP_FILE"
