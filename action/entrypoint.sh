#!/bin/sh -l

# Run main target
make -C /opt/link-checker main

# Clean cache
make -C /opt/link-checker clean-cache

# Use the provided PR number to construct the preview URL
PREVIEW_URL="deploy-preview-$INPUT_PRNUMBER--fluxcd.netlify.app"
export PREVIEW_URL

# Run with preview
make -C /opt/link-checker run_with_preview

# Normalize reports
make normalize

# Run summary
make summary

# Check summary results
/opt/link-checker/scripts/check_summary.sh

# TODO: the workflow should nag issues in the baseline
# /opt/link-checker/scripts/comment_on_pr.sh
