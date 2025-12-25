#!/usr/bin/env -S uv run --script

'''
Convert products from French Reparability indice dataset to Open Food Facts' CSV.

Mapping is read from mapping.csv file.

Script can be tested with:
echo -e "id_modele,nom_commercial,note_ir\\n1234569990123,Test Product,6.5" | \\
    python3 ir_data2opf_csv.py

Usage:
  python3 ir_data2opf_csv.py [source_csv] [--limit N] [--target TARGET]
    - source_csv: Path to the source CSV file. If not provided, reads from stdin.
    - --limit N: Limit the number of products to process to N.
    - --target TARGET: Target database for export. Choices are 'Product Opener' or 'Folksonomy Engine'.

Target defaults to 'Product Opener' if not specified.

Output is printed to stdout as CSV data.
'''

# /// script
# requires-python = ">=3.11"
# ///
import csv
import sys
import itertools
import argparse
import configparser
import os

# Paths to the files
MAPPING_CSV = 'mapping.csv'

# Parse command line arguments
parser = argparse.ArgumentParser(description=__doc__,
    formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument('source_csv', nargs='?', default=None, help='Source CSV file (default: stdin)')
parser.add_argument('--limit', type=int, default=None, help='Limit the number of products to process')
parser.add_argument('--target', type=str, default='Product Opener', 
                    choices=['Product Opener', 'Folksonomy Engine'],
                    help='Target database for export (default: Product Opener)')
args = parser.parse_args()

# Open CSV source from file or stdin, and check if it exists
if args.source_csv:
    if not os.path.isfile(args.source_csv):
        print(f"Error: File '{args.source_csv}' does not exist.", file=sys.stderr)
        sys.exit(1)
    if os.path.getsize(args.source_csv) == 0:
        print("Source CSV is empty.")
        sys.exit(1)
    source = open(args.source_csv, mode='r', encoding='utf-8')
elif sys.stdin.isatty():
    print("No source CSV file provided and stdin is not piped.")
    parser.print_help()
    sys.exit(1)
else:
    source = sys.stdin


def normalize_categories(value):
    """Normalize category values using a mapping dictionary."""
    category_mappings = {
        "ordinateur portable": "Ordinateur portable",
        "Lave-linge à chargement frontal (ou Lave-linge hublot)": "Lave-linge hublot",
        "Lave-linge à chargement par le haut (ou Lave-linge top)": "Lave-linge top",
        "Smartphone": "Smartphones",
    }
    # Apply all mappings
    for old_value, new_value in category_mappings.items():
        value = value.replace(old_value, new_value)
    return value


with source, open(MAPPING_CSV, mode='r', encoding='utf-8') as mapping:
    source_reader = csv.DictReader(source)
    mapping_reader = csv.DictReader(mapping)
    
    # Create a mapping list filtered by target database
    # Store source_column, target_column and transformation
    # Use a list to allow multiple mappings for the same source_column
    column_mappings = []
    for row in mapping_reader:
        if row.get('target_database') == args.target:
            column_mappings.append({
                'source_column': row['source_column'],
                'target_column': row['target_column'],
                'transformation': row.get('transformation', '').strip()
            })
    # Prepare the data for export
    products_to_import = []
    for row in source_reader:
        product = {}
        for mapping_info in column_mappings:
            source_col = mapping_info['source_column']
            if source_col in row:
                value = row[source_col]
                target_col = mapping_info['target_column']
                transformation = mapping_info['transformation']
                
                # Don't import row if "id_modele" value isn't an EAN code (applies to both targets)
                if target_col == "code":
                    if not (value.isdigit() and (len(value) == 8 or len(value) == 13)):
                        with open("invalid_rows.log", "w", encoding="utf-8") as log_file:
                            log_file.write(f"Skipping product with invalid EAN code: {value}\n")
                        product = None
                        break
                
                # Apply Product Opener specific transformations
                if args.target == "Product Opener":
                    # Special handling for "note_ir" column
                    if source_col == "note_ir" and value:
                        # Replace '.' with '-' and build the string
                        value = f"en:repairability-index-{str(value).replace('.', '-')}-france"
                    # Add "Open Products Facts" value to categories, separated by commas, and wrap in double quotes
                    if target_col == "categories" and value:
                        if "categories" in product and product["categories"]:
                            value = f'{product["categories"]},{value}'
                        value = normalize_categories(value)
                        # Always append "Open Products Facts" at the end
                        value = f'{value},Open Products Facts'
                
                # Generic handling for add_to_list transformation
                if transformation == "add_to_list":
                    if target_col in product and product[target_col]:
                        product[target_col] = f'{product[target_col]},{value}'
                    else:
                        product[target_col] = value
                # Generic handling for prefix_field transformation
                elif transformation == "prefix_field":
                    if target_col in product and product[target_col]:
                        # Remove final 's' from "Smartphones" if present
                        normalized_value = normalize_categories(value)
                        if normalized_value == "Smartphones":
                            normalized_value = "Smartphone"
                        product[target_col] = f'{normalized_value} - {product[target_col]}'
                    else:
                        product[target_col] = value
                else:
                    product[target_col] = value
        if product is not None:
            products_to_import.append(product)
    
    # Exit if no products to import
    if not products_to_import:
        print("No products to import.")
        sys.exit(2)

    # Print products as CSV data, limited by --limit flag if provided
    limit = args.limit

    # Get the list of fieldnames from the first product, if any
    if products_to_import:
        fieldnames = list(products_to_import[0].keys())
        writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames)
        writer.writeheader()
        for product in itertools.islice(products_to_import, limit):
            writer.writerow(product)
