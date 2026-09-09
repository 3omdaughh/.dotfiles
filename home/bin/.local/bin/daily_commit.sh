#!/bin/bash

# ----- CONFIGURATION -----
REPO_PATH="/home/omdaughh/Desktop/3omdaughh.github.io" 
COMMIT_MSG="${COMMIT_MSG:-Automated commit on $(date)}"
# If $COMMIT_MSG is not set, a default with timestamp is used.
# -------------------------

# Change to the repository directory
cd "$REPO_PATH" || {
    echo "[!] ERROR: Cannot change to $REPO_PATH" >&2
    exit 1
}

# Verify it's a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[!] ERROR: $REPO_PATH is not a Git repository" >&2
    exit 1
fi

# Execute the Git commands
echo "--- Running git add --all... ---"
git add --all

echo "--- Committing with message ---: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"

echo "--- Pushing to origin main... ---"
git push -u origin main

# Check result
if [ $? -eq 0 ]; then
    echo "--- Git push completed successfully at $(date) ---"
else
    echo "[!] ERROR: Git push failed at $(date)" >&2
    exit 1
fi
