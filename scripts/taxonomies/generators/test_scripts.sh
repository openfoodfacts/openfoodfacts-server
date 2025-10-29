#!/bin/bash
# Quick test script to verify all components work

echo "=== Testing Google Product Taxonomy Conversion Scripts ==="
echo ""

echo "Step 1: Extract existing data..."
python3 03_extract_existing_data.py > /tmp/test1.log 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Extraction successful"
    echo "  - $(grep 'Total categories:' /tmp/test1.log)"
    echo "  - $(grep 'Categories with Wikidata' /tmp/test1.log)"
else
    echo "✗ Extraction failed"
    exit 1
fi

echo ""
echo "=== All local tests passed! ==="
echo ""
echo "To fetch external data and generate full taxonomy:"
echo "  python3 00_run_all.py"
echo ""
echo "Generated files will be in:"
echo "  google_product_taxonomy_data/"
