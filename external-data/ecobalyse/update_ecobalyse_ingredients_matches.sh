#!/bin/bash
set -e

# This script updates ecobalyse ingredient properties in the OFF ingredients taxonomy.
# It re-runs the full pipeline:
#   1. Match ecobalyse base ingredients to OFF taxonomy tagids
#   2. Generate ecobalyse ingredient properties from processes.json
#   3. Remove existing ecobalyse properties from the ingredients taxonomy
#   4. Add the new properties
#   5. Run make lint
#   6. Run make build_taxonomies
#   7. Update all products with the new ecobalyse ingredient matches
#   8. Analyze missing ecobalyse ingredients

# Run from the repo root
cd "$(dirname "$0")/../.."

TAXONOMY_FILE="taxonomies/food/ingredients.txt"
PROPERTIES_FILE="external-data/ecobalyse/ecobalyse_ingredient_properties.csv"
CONTAINER="${OFF_BACKEND_CONTAINER:-po_off-backend-1}"

echo "=== Step 1: Matching ecobalyse base ingredients to OFF ingredients ==="
docker exec "$CONTAINER" bash -c "cd /opt/product-opener && perl external-data/ecobalyse/match_ecobalyse_base_ingredients_to_off.pl"

echo "=== Step 2: Generating ecobalyse ingredient properties ==="
docker exec "$CONTAINER" bash -c "cd /opt/product-opener && perl external-data/ecobalyse/extract_ecobalyse_ingredient_properties.pl"

echo "=== Step 3: Removing existing ecobalyse properties from $TAXONOMY_FILE ==="
bash scripts/taxonomies/remove_properties_from_taxonomy.sh \
	--taxonomy_file "$TAXONOMY_FILE" \
	--property_prefix "ecobalyse_"

echo "=== Step 4: Adding new ecobalyse properties to $TAXONOMY_FILE ==="
docker exec "$CONTAINER" bash -c "cd /opt/product-opener && perl scripts/taxonomies/add_properties_to_taxonomy.pl \
	--taxonomy_file $TAXONOMY_FILE \
	--properties_file $PROPERTIES_FILE"

echo "=== Step 5: Running make lint ==="
make lint

echo "=== Step 6: Building taxonomies ==="
make build_taxonomies

echo "=== Step 7: Updating all products with new ecobalyse ingredient matches ==="
docker exec "$CONTAINER" bash -c "cd /opt/product-opener && ./scripts/update_all_products.pl --analyze --query popularity_tags=top-10000-fr-scans-2025"

echo "=== Step 8: Analyzing missing ecobalyse ingredients ==="
docker exec "$CONTAINER" bash -c "cd /opt/product-opener && ./external-data/ecobalyse/analyze_missing_ecobalyse_ingredients.pl --query popularity_tags=top-10000-fr-scans-2025 --output missing_ecobalyse_ingredients.tsv"

echo "=== Done! Ecobalyse ingredient properties updated. ==="
