#!/bin/bash
set -e

echo "Setting up git and restoring taxonomies dates..."

# Setup git for origin main branch
git remote set-branches --add origin main
git fetch --no-tags --prune --progress --no-recurse-submodules --depth=5 origin main

# Restore taxonomies dates for files in taxonomies

# here we first restore dates from git for taxonomies to avoid build them all
# see https://stackoverflow.com/a/60984318/2886726
git ls-files taxonomies/ | xargs -I{} git log -1 --date=format:%Y%m%d%H%M.%S --format='touch -t %ad "{}"' "{}" | bash

echo "Setup complete."