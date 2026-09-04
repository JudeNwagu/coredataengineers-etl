#!/bin/bash
set -euo pipefail

export CSV_URL="${CSV_URL:?ERROR: Please set CSV_URL first, e.g. export CSV_URL='https://example.com/data.csv'}"

echo "Extract step starting..."