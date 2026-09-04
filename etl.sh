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

echo "Transform step starting..."

# Create the Transformed/ folder if it doesn't already exist.
mkdir -p Transformed

# --------------------------------------------------------------------------
# TRANSFORM: rename Variable_code -> variable_code, and keep only
# year, Value, Units, variable_code.
#
# We can't just split on every comma (awk -F','), because some fields
# in this file are wrapped in quotes and contain commas INSIDE them
# (e.g. "Sales, government funding, grants and subsidies", and Value
# fields like "728,225"). We proved this earlier: a naive split turned
# row 3 into 21 fields instead of 10.
#
# So instead, we parse each line character by character, and only
# treat a comma as a real delimiter when we are NOT inside quotes.
# --------------------------------------------------------------------------
awk '
# parse_csv: splits one line into the arr[] array, respecting quotes.
# Returns how many fields it found.
function parse_csv(line, arr,    n, i, c, field, inquotes) {
    n = 0
    field = ""
    inquotes = 0
    for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (c == "\"") {
            inquotes = !inquotes          # toggle in/out of a quoted section
        } else if (c == "," && inquotes == 0) {
            arr[++n] = field              # comma OUTSIDE quotes = real delimiter
            field = ""
        } else {
            field = field c               # comma INSIDE quotes = just a normal character
        }
    }
    arr[++n] = field
    return n
}

{
    # Every line (header and data) gets its trailing carriage-return
    # stripped (this file uses Windows-style line endings), then parsed
    # with our quote-aware function.
    gsub(/\r$/, "")
    nf = parse_csv($0, f)
}

NR==1 {
    # On the header row, find WHICH column number holds each field we need.
    for (i = 1; i <= nf; i++) {
        col = f[i]

        # The rename step: Variable_code -> variable_code
        if (col == "Variable_code") {
            col = "variable_code"
        }

        if (col == "Year")          year_idx    = i
        if (col == "Value")         value_idx   = i
        if (col == "Units")         units_idx   = i
        if (col == "variable_code") varcode_idx = i
    }

    # Safety check: if any column was not found, stop with a clear error
    # instead of silently producing broken output.
    if (!year_idx || !value_idx || !units_idx || !varcode_idx) {
        print "ERROR: required column not found in source file" > "/dev/stderr"
        exit 1
    }

    # Print the new header row for our output file
    print "year,Value,Units,variable_code"
    next
}

{
    # For every data row, pull out just the four fields we need,
    # using the column positions we found from the header.
    y = f[year_idx]; v = f[value_idx]; u = f[units_idx]; c = f[varcode_idx]

    # If any of these values themselves contain a comma (like
    # Value = "728,225"), wrap them back in quotes so the output
    # stays valid, correctly-readable CSV.
    if (y ~ /,/) y = "\"" y "\""
    if (v ~ /,/) v = "\"" v "\""
    if (u ~ /,/) u = "\"" u "\""
    if (c ~ /,/) c = "\"" c "\""

    print y "," v "," u "," c
}
' raw/year_finance.csv > Transformed/2023_year_finance.csv

# Confirm the transformed file was actually created and isn't empty.
if [ -s Transformed/2023_year_finance.csv ]; then
    echo "CONFIRMED: Transformed/2023_year_finance.csv was created."
    echo "Preview:"
    head -n 5 Transformed/2023_year_finance.csv
else
    echo "ERROR: Transform step failed."
    exit 1
fi

echo "Load step starting..."

# Create the Gold/ folder if it doesn't already exist.
mkdir -p Gold

# --------------------------------------------------------------------------
# LOAD: copy the transformed file into the Gold/ folder.
# This represents moving the cleaned data into its final destination,
# ready for consumption (reporting, analysis, etc.).
# --------------------------------------------------------------------------
cp Transformed/2023_year_finance.csv Gold/

# Confirm the file actually landed in Gold/.
if [ -s Gold/2023_year_finance.csv ]; then
    echo "CONFIRMED: File successfully loaded into Gold/."
else
    echo "ERROR: Load step failed."
    exit 1
fi

echo "ETL pipeline completed successfully."