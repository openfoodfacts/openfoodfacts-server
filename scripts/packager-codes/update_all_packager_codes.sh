#!/bin/bash

SCRIPTS_DIR=$(dirname "$0")
failed_scripts=()

# Define a function for running a script with exception handling
run_script() {
    echo "🚀 Starting $1..."
    if $SCRIPTS_DIR/$1; then
        echo "✅ Successfully executed $1."
    else
        echo "❌ Error occurred in $1."
        failed_scripts+=("$1")
    fi
}

# List of scripts to run
scripts=(
    # "de-packagers-refresh.pl"
    # "ee-packagers-xml2tsv.pl"
    # "es-packagers-html2csv.pl"
    # "fi-packagers-xls2csv.pl"
    # "fr-packagers-refresh.pl"
    "hr-packagers-refresh.py"
    # "poland_packager_code.py"
    # "portugal-concatenate-csv-sections.py"
    # "portugal-geocode.sh"
    # "se-packagers-html2tsv.pl"
)

# Run each script
for script in "${scripts[@]}"; do
    run_script "$script"
done

# Update packager codes database
echo ""
echo "🔄 Updating packager codes database..."
if perl ../update_packager_codes.pl; then
    echo "✅ Successfully updated packager codes database."
else
    echo "❌ Error updating packager codes database."
    exit 1
fi

# Report results
echo ""
if [ ${#failed_scripts[@]} -gt 0 ]; then
    echo "❌ FAILED: ${failed_scripts[*]}"
    exit 1
else
    echo "🎉 All scripts executed successfully!"
    echo "✓ Packager codes database updated"
fi
