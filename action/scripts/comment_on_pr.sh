#!/bin/bash
set -e

LINE_COUNT=$(wc -l < pr-summary.csv)

echo "$INPUT_TOKEN" | gh auth login --with-token

if [ "$LINE_COUNT" -le 1 ]; then
    # Using GitHub CLI to comment on the PR.
    gh pr comment ${INPUT_PRNUMBER} --body "Warning: Some unresolved baseline issues are present."
fi
