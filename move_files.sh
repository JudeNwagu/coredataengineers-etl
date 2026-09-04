#!/bin/bash
set -euo pipefail
# -e: stop on any error | -u: error on unset variables | -o pipefail: catch errors in piped commands

echo "Move files script starting..."

SOURCE_DIR="${1:?ERROR: Please provide a source folder. Usage: ./move_files.sh <source_folder>}"
DEST_DIR="json_and_CSV"
# $1 = first argument passed to the script; DEST_DIR name is fixed per assignment

echo "Source folder: $SOURCE_DIR"
echo "Destination folder: $DEST_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Source folder '$SOURCE_DIR' does not exist."
    exit 1
fi

mkdir -p "$DEST_DIR"

shopt -s nullglob nocaseglob
# nullglob: unmatched *.csv expands to nothing, not a literal string
# nocaseglob: matches .CSV/.Csv/.json/.JSON etc regardless of case

files=("$SOURCE_DIR"/*.csv "$SOURCE_DIR"/*.json)

if [ ${#files[@]} -eq 0 ]; then
    echo "No CSV or JSON files found in '$SOURCE_DIR'. Nothing to move."
    exit 0
fi

echo "Found ${#files[@]} file(s) to move."

moved_count=0
for f in "${files[@]}"; do
    mv -v "$f" "$DEST_DIR"/   # -v prints each move as confirmation
    moved_count=$((moved_count + 1))
done

echo "CONFIRMED: Moved $moved_count file(s) into '$DEST_DIR'."