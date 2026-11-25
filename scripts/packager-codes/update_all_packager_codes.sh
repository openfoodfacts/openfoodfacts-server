#!/bin/bash

SCRIPTS_DIR=$(dirname "$0")
SKIP_DB_UPDATE=false
if [ "${1:-}" = "--skip-db-update" ]; then
    SKIP_DB_UPDATE=true
fi
failed_scripts=()

# Countries to process with unified main.py
countries=(
    "dk"
    "fi"
    "hr"
)

# Process countries using unified main.py
for country in "${countries[@]}"; do
    echo "🚀 Starting $country..."
    if python3 $SCRIPTS_DIR/main.py "$country"; then
        echo "✅ Successfully processed $country."
    else
        echo "❌ Error occurred processing $country."
        failed_scripts+=("main.py $country")
    fi
done

# Update packager codes database
if [ "$SKIP_DB_UPDATE" = false ]; then
    echo ""
    echo "🔄 Updating packager codes database..."
    if perl ../update_packager_codes.pl; then
        echo "✅ Successfully updated packager codes database."
    else
        echo "❌ Error updating packager codes database."
        exit 1
    fi
fi

# Report results
echo ""
if [ ${#failed_scripts[@]} -gt 0 ]; then
    echo "❌ FAILED: ${failed_scripts[*]}"
    exit 1
else
    echo "🎉 All scripts executed successfully!"
    if [ "$SKIP_DB_UPDATE" = false ]; then
        echo "✓ Packager codes database updated"
    fi
fi
