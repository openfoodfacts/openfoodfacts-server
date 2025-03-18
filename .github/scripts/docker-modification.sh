#!/bin/bash

set -e

# Check each changed file
for file in "$@"; do
  if [[ $file == Dockerfile* || 
        $file == docker-compose.yml || 
        $file == docker/* || 
        $file == cpanfile* || 
        $file == conf/apache* ]]; then
    echo "docker_modified=true" >> "$GITHUB_OUTPUT"
    echo "Docker files were modified: $file"
    exit 0
  fi
done

# If no Docker-related files were changed
echo "docker_modified=false" >> "$GITHUB_OUTPUT"
echo "No Docker files were modified"