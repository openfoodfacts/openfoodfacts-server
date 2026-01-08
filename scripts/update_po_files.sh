#!/usr/bin/env bash

# Script to update all .po files from their corresponding .pot files
# This uses msgmerge from gettext to update translations while preserving existing translations

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🥫 Updating .po files from .pot files..."

# Check if gettext is installed
if ! command -v msgmerge &> /dev/null; then
    echo -e "${RED}Error: msgmerge not found. Please install gettext tools.${NC}"
    echo "On Debian/Ubuntu: sudo apt-get install gettext"
    exit 1
fi

# Function to update po files from a pot file
update_po_files_from_pot() {
    local pot_file=$1
    local po_dir=$(dirname "$pot_file")
    local updated_count=0
    
    if [ ! -f "$pot_file" ]; then
        echo -e "${RED}Error: POT file not found: $pot_file${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Processing: $pot_file${NC}"
    
    # Find all .po files in the same directory
    for po_file in "$po_dir"/*.po; do
        if [ -f "$po_file" ]; then
            local po_basename=$(basename "$po_file")
            echo -n "  → Updating $po_basename... "
            
            # Use msgmerge to update the .po file
            # --update: update the .po file in place
            # --backup=none: don't create backup files
            # --quiet: less verbose output
            # --previous: keep previous msgid strings as comments for translators
            if msgmerge --update --backup=none --quiet --previous "$po_file" "$pot_file" 2>&1; then
                echo -e "${GREEN}✓${NC}"
                updated_count=$((updated_count + 1))
            else
                echo -e "${RED}✗${NC}"
                return 1
            fi
        fi
    done
    
    echo -e "${GREEN}Updated $updated_count .po files from $(basename "$pot_file")${NC}"
    return 0
}

# Track if any errors occurred
errors=0

# Update common.pot -> *.po files
if [ -f "po/common/common.pot" ]; then
    if ! update_po_files_from_pot "po/common/common.pot"; then
        errors=$((errors + 1))
    fi
else
    echo -e "${YELLOW}Warning: po/common/common.pot not found${NC}"
fi

echo ""

# Update tags.pot -> *.po files
if [ -f "po/tags/tags.pot" ]; then
    if ! update_po_files_from_pot "po/tags/tags.pot"; then
        errors=$((errors + 1))
    fi
else
    echo -e "${YELLOW}Warning: po/tags/tags.pot not found${NC}"
fi

echo ""

if [ $errors -gt 0 ]; then
    echo -e "${RED}❌ Completed with $errors error(s)${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All .po files updated successfully${NC}"
    exit 0
fi
