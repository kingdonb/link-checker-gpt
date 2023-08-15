#!/bin/bash
set -e

LINE_COUNT=$(wc -l < pr-summary.csv)

if [ "$LINE_COUNT" -le 1 ]; then
    # Using GitHub CLI to comment on the PR.
    gh pr comment ${{ github.event.pull_request.number }} --body "Warning: Some unresolved baseline issues are present. Please check the attached baseline-unresolved.csv."
fi
