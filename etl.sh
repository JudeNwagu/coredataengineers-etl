#!/bin/bash
# Shebang line: tells the system to run this script using bash.

set -euo pipefail
# -e          : stop the script immediately if any command fails
# -u          : treat use of an undefined variable as an error
# -o pipefail : catch failures anywhere in a piped chain of commands,
#               not just the last command in the pipe

# --------------------------------------------------------------------------
# CONFIGURATION: Environment variable for the CSV source URL
# --------------------------------------------------------------------------
# ${CSV_URL:?message} means: use CSV_URL if it's already set in the
# environment; if it's NOT set, print "message" and exit immediately.
# This satisfies the assignment requirement to use an env variable
# for the URL instead of hard-coding it into the script.
export CSV_URL="${CSV_URL:?ERROR: Please set CSV_URL first, e.g. export CSV_URL='https://example.com/data.csv'}"

echo "Extract step starting..."

# --------------------------------------------------------------------------
# EXTRACT: Download the CSV and save it into the raw/ folder
# --------------------------------------------------------------------------

# Create the raw/ folder if it doesn't already exist.
# -p = don't throw an error if the folder is already there.
mkdir -p raw

# Download the file from CSV_URL and save it as raw/year_finance.csv
# -s : silent mode (hides the progress bar)
# -S : but still show an error message if the download fails
# -L : follow redirects (some download links redirect before serving the file)
# -o : write the downloaded content to this specific file path
curl -sSL "$CSV_URL" -o raw/year_finance.csv

# Confirm the download actually worked.
# [ -s FILE ] checks: does this file exist AND have a size greater than 0 bytes?
# (this is different from curl's -s flag above; it's a bash file-test operator)
if [ -s raw/year_finance.csv ]; then
    echo "CONFIRMED: raw/year_finance.csv exists and is non-empty."
else
    echo "ERROR: Download failed or file is empty."
    exit 1
fi