#!/bin/bash
# Shebang: run this file with bash.

set -euo pipefail
# Same safety flags as etl.sh -- stop on error, catch undefined
# variables, and catch failures in piped commands.

echo "Move files script starting..."

# --------------------------------------------------------------------------
# ARGUMENTS: source folder (required) and destination folder (fixed name,
# as required by the assignment: "json_and_CSV")
# --------------------------------------------------------------------------
# $1 refers to the first argument passed when running the script, e.g.:
#   ./move_files.sh sample_input
# ${1:?message} means: use $1 if provided, otherwise print the error
# message and stop -- same pattern we used for CSV_URL in etl.sh.
SOURCE_DIR="${1:?ERROR: Please provide a source folder. Usage: ./move_files.sh <source_folder>}"
DEST_DIR="json_and_CSV"

echo "Source folder: $SOURCE_DIR"
echo "Destination folder: $DEST_DIR"

# Check the source folder actually exists before we try to use it.
if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Source folder '$SOURCE_DIR' does not exist."
    exit 1
fi

# Create the destination folder if it doesn't already exist.
mkdir -p "$DEST_DIR"

# --------------------------------------------------------------------------
# Find and move all .csv and .json files (case-insensitive) from the
# source folder into the destination folder.
# --------------------------------------------------------------------------
# shopt sets shell options:
#   nullglob   -> if a pattern like *.csv matches nothing, it expands to
#                 NOTHING instead of the literal text "*.csv". Without
#                 this, if there were zero CSV files, the script would
#                 try to move a file literally named "*.csv" and fail.
#   nocaseglob -> matches .csv/.CSV/.Csv and .json/.JSON the same way,
#                 so file extension casing doesn't matter.
shopt -s nullglob nocaseglob

# Build an array of every matching file found in the source folder.
files=("$SOURCE_DIR"/*.csv "$SOURCE_DIR"/*.json)

# ${#files[@]} gives the number of items in the array.
# If it's zero, there's nothing to move -- exit cleanly, not as an error,
# since "no matching files" isn't necessarily a failure.
if [ ${#files[@]} -eq 0 ]; then
    echo "No CSV or JSON files found in '$SOURCE_DIR'. Nothing to move."
    exit 0
fi

echo "Found ${#files[@]} file(s) to move."

# Move every file found. -v (verbose) prints what it's doing as it goes,
# which doubles as our "confirmation" that each file actually moved.
moved_count=0
for f in "${files[@]}"; do
    mv -v "$f" "$DEST_DIR"/
    moved_count=$((moved_count + 1))
done

echo "CONFIRMED: Moved $moved_count file(s) into '$DEST_DIR'."