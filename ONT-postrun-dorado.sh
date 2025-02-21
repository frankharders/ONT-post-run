#!/bin/bash

# Get the current working directory
current_working_dir=$(pwd)

# URL of the GitHub repository
REPO_URL="https://github.com/frankharders/ONT-post-run.git"

# Clone the repository
git clone "$REPO_URL"

# Extract the repository name from the URL
REPO_NAME=$(basename "$REPO_URL" .git)

# Change to the repository directory
cd "$REPO_NAME"

# Make all bash scripts executable
find . -type f -name "*.sh" -exec chmod +x {} \;

# Move all bash scripts to the current working directory
find . -type f -name "*.sh" -exec mv {} "$current_working_dir" \;

# Return to the original working directory
cd "$current_working_dir"

# Remove the cloned repository directory
rm -rf "$REPO_NAME"

echo "Downloaded, made executable, and moved all bash scripts to $current_working_dir"


./pod52fastq-v01.sh

exit 0
