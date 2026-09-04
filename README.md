# CoreDataEngineers – Bash ETL Pipeline

A simple ETL (Extract, Transform, Load) pipeline written entirely in Bash,
scheduled with cron, plus a separate utility script for organizing CSV/JSON
files. Built as a Data Engineer onboarding task at CoreDataEngineers.

## Project structure

```
├── etl.sh # Main ETL pipeline script
├── move_files.sh # Moves CSV/JSON files into json_and_CSV/
├── README.md
└── .gitignore
```


Running the scripts will also generate these folders (not tracked in git —
see `.gitignore`):
- `raw/` — downloaded source CSV
- `Transformed/` — cleaned, column-filtered CSV
- `Gold/` — final loaded output
- `json_and_CSV/` — output of `move_files.sh`

## 1. The ETL script (`etl.sh`)

### What it does

| Stage | Action |
|---|---|
| **Extract** | Downloads a CSV from the URL in the `CSV_URL` environment variable, saves it to `raw/`, and confirms the file exists and is non-empty. |
| **Transform** | Renames the column `Variable_code` → `variable_code`, keeps only `year, Value, Units, variable_code`, and saves the result to `Transformed/2023_year_finance.csv`. Uses a custom quote-aware CSV parser (see Notes below) since some source fields contain commas inside quotes. |
| **Load** | Copies the transformed file into `Gold/` and confirms it landed there. |

Every step prints a status message so progress is visible in the terminal
(or in the cron log file).


### Example output

A sample of the actual transformed data (`Transformed/2023_year_finance.csv`
and `Gold/2023_year_finance.csv` — Load produces an identical copy):

    year,Value,Units,variable_code
    2023,930995,Dollars (millions),H01
    2023,821630,Dollars (millions),H04
    2023,84354,Dollars (millions),H05
    2023,25010,Dollars (millions),H07
    2023,832964,Dollars (millions),H08

Note: some `Value` fields in the full file contain thousands-separator
commas (e.g. `"728,225"`) and are correctly wrapped in quotes to keep the
CSV valid — see "Notes on the Transform step" below for how this is
handled.


### Why an environment variable for the URL?

Hard-coding a URL inside a script is bad practice — the URL might change,
and you may not want to expose it directly in version control. Instead,
the script reads it from the environment at run time:

    export CSV_URL="${CSV_URL:?ERROR: Please set CSV_URL first}"

`${VAR:?message}` is a Bash safeguard: if `CSV_URL` isn't set, the script
prints the message and exits immediately instead of failing later in a
confusing way.

### How to run it

    export CSV_URL="<your-csv-source-url>"
    chmod +x etl.sh
    ./etl.sh

Example using the actual New Zealand Stats dataset this project was built
and tested against:

    export CSV_URL="https://www.stats.govt.nz/assets/Uploads/Annual-enterprise-survey/Annual-enterprise-survey-2023-financial-year-provisional/Download-data/annual-enterprise-survey-2023-financial-year-provisional.csv"
    ./etl.sh

### Notes on the Transform step

While building this pipeline, testing against the real dataset revealed
two things that a naive approach would have gotten wrong:

- The source column is named `Year` (capital Y), not `year` — confirmed
  by inspecting the real header row rather than assuming it.
- Some fields contain commas *inside* quotes (e.g. a Variable_name value
  like `"Sales, government funding, grants and subsidies"`, and Value
  fields like `"728,225"`). A naive `awk -F','` split breaks these apart
  incorrectly — confirmed by testing: row 3 of the real file split into
  21 fields instead of the correct 10.

  To handle this correctly without external tools, `etl.sh` uses a
  character-by-character CSV parser (a small `awk` function) that only
  treats a comma as a field separator when it is *not* inside a pair of
  double quotes. This was verified against the full file: all 50,986
  rows parse to exactly 4 output fields, with no data shifted into the
  wrong column.

## 2. Scheduling with cron (daily at 12:00 AM)

cron runs commands on a schedule defined by a crontab. Each line has five
time fields, followed by the command to run:

    minute  hour  day-of-month  month  day-of-week   command
      0       0         *          *         *       command-to-run

`0 0 * * *` means "every day at midnight."

### Setting it up

    crontab -e

Add this line (using the absolute path — cron does not know your shell's
working directory, and does not load your `~/.bashrc`, so `CSV_URL` must
be set inline):

    0 0 * * * CSV_URL="<your-csv-source-url>" /path/to/your/etl.sh >> /path/to/your/etl.log 2>&1

Actual entry used for this project:

    0 0 * * * CSV_URL="https://www.stats.govt.nz/assets/Uploads/Annual-enterprise-survey/Annual-enterprise-survey-2023-financial-year-provisional/Download-data/annual-enterprise-survey-2023-financial-year-provisional.csv" /home/judoski/coredataengineers-etl/etl.sh >> /home/judoski/coredataengineers-etl/etl.log 2>&1

Save and exit, then confirm:

    crontab -l

### Verifying it actually runs

Rather than waiting until midnight to find out if it works, this was
tested live: a temporary one-time entry was added for a few minutes in
the future, left to fire naturally, and the resulting `etl.log` was
checked afterward to confirm the full Extract → Transform → Load
sequence completed successfully via cron (not just when run manually).
The temporary entry was removed afterward, leaving only the real
midnight schedule.

**Note (WSL-specific):** on Windows/WSL, the `cron` daemon does not
always start automatically the way it does on a normal always-on Linux
server. Check its status with `service cron status` before relying on
scheduled jobs; if it isn't running, start it with `sudo service cron
start`.

## 3. File-organizing script (`move_files.sh`)

Moves every `.csv` and `.json` file (case-insensitive) from a given source
folder into a folder named `json_and_CSV`. Works whether there's one file,
several, or none at all.

### How to run it

    chmod +x move_files.sh
    ./move_files.sh <source_folder>

Example:

    ./move_files.sh sample_input

### Design notes

- The source folder is passed as an argument (`$1`), not hard-coded, so
  the same script works against any folder.
- `shopt -s nullglob` prevents the script from trying to move a literal
  file named `*.csv` if zero CSV files exist — without this option, an
  unmatched glob pattern is left as-is instead of expanding to nothing.
- `shopt -s nocaseglob` makes the match case-insensitive, so `.CSV`,
  `.Csv`, `.JSON`, etc. are also picked up.
- If no matching files are found, the script prints a message and exits
  cleanly (exit code 0) rather than treating "nothing to move" as an
  error — this was tested directly against an empty folder to confirm
  the script doesn't crash or behave unexpectedly in that case.

## 4. Version control

This project is tracked with git, with small, incremental commits made
after each working piece (Extract, then Transform, then Load, then cron
setup, then move_files.sh, etc.) rather than one large commit at the end.

Basic workflow used throughout:

    git add <file>
    git commit -m "Describe what changed"

To push this repository to GitHub for the first time:

    git remote add origin https://github.com/<your-username>/<repo-name>.git
    git branch -M main
    git push -u origin main

For subsequent changes:

    git add .
    git commit -m "Describe what changed"
    git push