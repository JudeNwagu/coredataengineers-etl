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