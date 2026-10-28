#!/bin/bash
set -e

TAXONOMY_FILE=""
PROPERTY_PREFIX=""

while [ $# -gt 0 ]; do
    case "$1" in
        --taxonomy_file)
            TAXONOMY_FILE="$2"
            shift 2
            ;;
        --property_prefix)
            PROPERTY_PREFIX="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ -z "$TAXONOMY_FILE" ] || [ -z "$PROPERTY_PREFIX" ]; then
    echo "Usage: $0 --taxonomy_file <file> --property_prefix <prefix>"
    exit 1
fi

grep -v "^${PROPERTY_PREFIX}" "$TAXONOMY_FILE" > "${TAXONOMY_FILE}.tmp" && mv "${TAXONOMY_FILE}.tmp" "$TAXONOMY_FILE"
