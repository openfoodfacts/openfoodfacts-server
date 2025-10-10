#!/usr/bin/env -S uv run --script

'''
Convert products from French Reparability indice dataset to Open Food Facts' CSV.

Mapping is read from mapping.csv file.
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
args = parser.parse_args()

# Open source CSV from argument or stdin, and check if it exists
if args.source_csv:
    if not os.path.isfile(args.source_csv):
        print(f"Error: File '{args.source_csv}' does not exist.", file=sys.stderr)
        sys.exit(1)
    source = open(args.source_csv, mode='r', encoding='utf-8')
elif sys.stdin.isatty():
    print("No source CSV file provided and stdin is not piped.")
    parser.print_help()
    sys.exit(1)
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
    # Prepare the data for Open Products Facts
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
                # Add "Open Products Facts" value to categories, separated by commas, and wrap in double quotes
                if target_col == "categories" and value:
                    if "categories" in product and product["categories"]:
                        value = f'{product["categories"]},{value}'
                    # Replace "ordinateur portable" by "Ordinateur portable"
                    value = value.replace("ordinateur portable", "Ordinateur portable")
                    # Replace "Lave-linge à chargement frontal (ou Lave-linge hublot)" by "Lave-linge hublot"
                    value = value.replace("Lave-linge à chargement frontal (ou Lave-linge hublot)", "Lave-linge hublot")
                    # Replace "Lave-linge à chargement par le haut (ou Lave-linge top)" by "Lave-linge top"
                    value = value.replace("Lave-linge à chargement par le haut (ou Lave-linge top)", "Lave-linge top")
                    # Replace "Smartphone" by "Smartphones"
                    value = value.replace("Smartphone", "Smartphones")
                    # Always append "Open Products Facts" at the end
                    value = f'{value},Open Products Facts'
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
