#!/bin/sh -l

# Run main target
make -C /opt/link-checker main

# Clean cache
make -C /opt/link-checker clean-cache

# Use the provided PR number to construct the preview URL
# INPUT_PREVIEWURL="deploy-preview-$INPUT_PRNUMBER--fluxcd.netlify.app"
# export PREVIEWURL
export PRODUCTION_URL="$INPUT_PRODUCTIONDOMAIN"
export PREVIEW_URL="$INPUT_PREVIEWDOMAIN"

# Run with preview
make -C /opt/link-checker run_with_preview

# Normalize reports
make -C /opt/link-checker normalize

# Run summary
make -C /opt/link-checker summary

# Check summary results
make -C /opt/link-checker check-summary

# TODO: the workflow should nag issues in the baseline
# /opt/link-checker/scripts/comment_on_pr.sh
