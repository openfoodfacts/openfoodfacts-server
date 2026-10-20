#!/bin/bash
set -e

# ANSI Color definitions
BOLD="\033[1m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

echo "::group::🐙 Setting up git and restoring taxonomy timestamps"
echo -e "${CYAN}${BOLD}==> Configuring Git repository for CI...${RESET}"

# Setup git for origin main branch
echo -e "${CYAN}• Fetching origin/main branch metadata...${RESET}"
git remote set-branches --add origin main
git fetch --no-tags --prune --progress --no-recurse-submodules --depth=5 origin main

# Restore taxonomies dates for files in taxonomies
# Here we restore dates from git for taxonomies to avoid rebuilding them all
# See https://stackoverflow.com/a/60984318/2886726
echo -e "${CYAN}• Restoring taxonomy file timestamps from git history...${RESET}"
echo -e "${YELLOW}  (Preserving timestamps prevents Make from unnecessarily rebuilding unmodified taxonomies)${RESET}"

git ls-files taxonomies/ | xargs -I{} git log -1 --date=format:%Y%m%d%H%M.%S --format='touch -t %ad "{}"' "{}" | bash

echo -e "${GREEN}${BOLD}✅ Git setup and taxonomy timestamps restored successfully.${RESET}"
echo "::endgroup::"