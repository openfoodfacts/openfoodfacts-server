#!/bin/bash

set -e
# Check each changed file
for file in $@; do
  if ! echo "$file" | grep -E -q '\.md$|^docs/.*\.(md|yaml|yml)$|^docs/'; then
    echo "code_modified=true" >> "$GITHUB_OUTPUT"
    exit 0
  fi
done

# If only Markdown, YAML files in docs, or other docs files are changed
echo "code_modified=false" >> "$GITHUB_OUTPUT"