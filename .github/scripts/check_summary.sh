#!/bin/bash
set -e

LINE_COUNT=$(wc -l < pr-summary.csv)

if [ "$LINE_COUNT" -gt 1 ]; then
    echo "Issues found in PR. Attaching pr-summary.csv for review..."
else
    echo "No direct issues found in PR. Attaching baseline-unresolved.csv for reference..."
fi
