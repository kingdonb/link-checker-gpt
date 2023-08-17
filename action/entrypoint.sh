#!/bin/sh -l

# Run main target
bundle exec make main

# Clean cache
make clean-cache

# Use the provided PR number to construct the preview URL
PREVIEW_URL="deploy-preview-$INPUT_PRNUMBER--fluxcd.netlify.app"
export PREVIEW_URL

# Run with preview
bundle exec make run_with_preview

# Normalize reports
make normalize

# Run summary
bundle exec make summary

# Check summary results
./scripts/check_summary.sh

# TODO: the workflow should nag issues in the baseline
# ./scripts/comment_on_pr.sh
