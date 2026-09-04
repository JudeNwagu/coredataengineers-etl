#!/bin/bash
set -euo pipefail
# -e: stop on any error | -u: error on unset variables | -o pipefail: catch errors in piped commands

export CSV_URL="${CSV_URL:?ERROR: Please set CSV_URL first, e.g. export CSV_URL='https://example.com/data.csv'}"
# Require CSV_URL to be set in the environment (no hard-coded URL)

echo "Extract step starting..."

# --- EXTRACT ---
mkdir -p raw                                  # create raw/ folder if missing
curl -sSL "$CSV_URL" -o raw/year_finance.csv  # -s silent, -S show errors, -L follow redirects

if [ -s raw/year_finance.csv ]; then          # -s = file exists AND is non-empty
    echo "CONFIRMED: raw/year_finance.csv exists and is non-empty."
else
    echo "ERROR: Download failed or file is empty."
    exit 1
fi

echo "Transform step starting..."

# --- TRANSFORM ---
mkdir -p Transformed  # create Transformed/ folder if missing

awk '
# parse_csv: splits a line into arr[], respecting commas inside quotes
function parse_csv(line, arr,    n, i, c, field, inquotes) {
    n = 0; field = ""; inquotes = 0
    for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (c == "\"") inquotes = !inquotes                       # toggle inside/outside quotes
        else if (c == "," && inquotes == 0) { arr[++n] = field; field = "" }  # real delimiter
        else field = field c                                      # part of current field
    }
    arr[++n] = field
    return n
}

{
    gsub(/\r$/, "")            # strip Windows line-ending character
    nf = parse_csv($0, f)      # parse this line into array f[]
}

NR==1 {
    # Header row: find the column number for each field we need
    for (i = 1; i <= nf; i++) {
        col = f[i]
        if (col == "Variable_code") col = "variable_code"  # rename step

        if (col == "Year")          year_idx    = i   # source column is "Year", capital Y
        if (col == "Value")         value_idx   = i
        if (col == "Units")         units_idx   = i
        if (col == "variable_code") varcode_idx = i
    }

    if (!year_idx || !value_idx || !units_idx || !varcode_idx) {
        print "ERROR: required column not found in source file" > "/dev/stderr"
        exit 1
    }

    print "year,Value,Units,variable_code"   # write new header
    next
}

{
    # Data row: pull out just the 4 columns we need
    y = f[year_idx]; v = f[value_idx]; u = f[units_idx]; c = f[varcode_idx]

    # Re-wrap in quotes if the value itself contains a comma (e.g. "728,225")
    if (y ~ /,/) y = "\"" y "\""
    if (v ~ /,/) v = "\"" v "\""
    if (u ~ /,/) u = "\"" u "\""
    if (c ~ /,/) c = "\"" c "\""

    print y "," v "," u "," c
}
' raw/year_finance.csv > Transformed/2023_year_finance.csv

if [ -s Transformed/2023_year_finance.csv ]; then
    echo "CONFIRMED: Transformed/2023_year_finance.csv was created."
    echo "Preview:"
    head -n 5 Transformed/2023_year_finance.csv
else
    echo "ERROR: Transform step failed."
    exit 1
fi

echo "Load step starting..."

# --- LOAD ---
mkdir -p Gold                                       # create Gold/ folder if missing
cp Transformed/2023_year_finance.csv Gold/          # copy final file into Gold/

if [ -s Gold/2023_year_finance.csv ]; then
    echo "CONFIRMED: File successfully loaded into Gold/."
else
    echo "ERROR: Load step failed."
    exit 1
fi

echo "ETL pipeline completed successfully."