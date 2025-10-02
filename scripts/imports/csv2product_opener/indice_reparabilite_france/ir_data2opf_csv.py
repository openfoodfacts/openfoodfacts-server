#!/usr/bin/env -S uv run --script

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
parser = argparse.ArgumentParser(description="Convert products from CSV to Open Food Facts' CSV.")
parser.add_argument('source_csv', nargs='?', default=None, help='Source CSV file (default: stdin)')
parser.add_argument('--limit', type=int, default=None, help='Limit the number of products to process')
args = parser.parse_args()

# Open source CSV from argument or stdin
if args.source_csv:
    source = open(args.source_csv, mode='r', encoding='utf-8')
else:
    source = sys.stdin

# Check if source is empty
first_char = source.read(1)
if not first_char:
    parser.print_help()
    sys.exit("Source CSV is empty.")


with source, open(MAPPING_CSV, mode='r', encoding='utf-8') as mapping:
    source_reader = csv.DictReader(source)
    mapping_reader = csv.DictReader(mapping)
    
    # Create a mapping dictionary only for target_database == "Product Opener"
    column_mapping = {
        row['source_column']: row['target_column']
        for row in mapping_reader
        if row.get('target_database') == "Product Opener"
    }
    # Prepare the data for OpenFoodFacts
    products_to_import = []
    for row in source_reader:
        product = {}
        for source_col, target_col in column_mapping.items():
            if source_col in row:
                value = row[source_col]
                # Special handling for "note_ir" column
                if source_col == "note_ir" and value:
                    # Replace '.' with '-' and build the string
                    value = f"repairability-index-{str(value).replace('.', '-')}-france"
                # Don't import row if "id_modele" value isn't an EAN code
                if target_col == "code":
                    if not (value.isdigit() and (len(value) == 8 or len(value) == 13)):
                        with open("invalid_rows.log", "a", encoding="utf-8") as log_file:
                            log_file.write(f"Skipping product with invalid EAN code: {value}\n")
                        product = None
                        break
                product[target_col] = value
        if product is not None:
            products_to_import.append(product)
    
    # Print products as CSV data, limited by --limit flag if provided
    limit = args.limit

    # Get the list of fieldnames from the first product, if any
    if products_to_import:
        fieldnames = list(products_to_import[0].keys())
        writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames)
        writer.writeheader()
        for product in itertools.islice(products_to_import, limit):
            writer.writerow(product)
