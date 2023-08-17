#!/bin/bash
set -e

LINE_COUNT=$(wc -l < pr-summary.csv)

if [ "$LINE_COUNT" -gt 1 ]; then
    echo "Issues found in PR. Read the summary report above."
else
    echo "No direct issues found in PR." # TODO: Attaching baseline-unresolved.csv for reference...
fi
