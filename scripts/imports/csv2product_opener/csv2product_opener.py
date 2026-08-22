#!/usr/bin/env -S uv run --script

'''
Import products from standardized CSV to Open X Facts. Credentials are read from config.ini file.

Script can be tested with:
echo -e "code,product_name\\n123456990123,Test Product" | \\
    python3 csv2product_opener.py

or

cat source.csv | csv2product_opener.py --limit 1

or

python3 csv2product_opener.py source.csv --limit 1
'''

# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "openfoodfacts>=3.1.0,<3.2.0",
# ]
# ///

import csv
import sys
from openfoodfacts import API, APIVersion, Country, Environment, Flavor
import itertools
import argparse
import configparser
import os
import time


# Read command line arguments
parser = argparse.ArgumentParser(description=__doc__,
    formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument('csv_file',
    nargs='?',
    default=None,
    help='Path to the CSV file (defaults to stdin if not provided)')
parser.add_argument(
    '--limit', 
    type=int,
    default=None,
    help='Limit the number of products to process')
parser.add_argument(
    '--environment', '-e',
    choices=['net', 'org'],
    default='net',
    help=(
        'Open Food Facts environment to use: "net" (default) or "org". '
        '"net" does not work with "opf", "obf", or "opff" flavors. '
    )
)
parser.add_argument(
    '--country',
    default='world',
    help=(
        'Country code to use for Open X Facts (default: "world"). '
        'All countries have a default language except "world" which defaults to English. '
        'For example, "fr", for France, defaults to French.'
    )
)
parser.add_argument(
    '--flavor', '-f',
    choices=['off', 'opf', 'obf', 'opff'],
    help='Open Food Facts API flavor to use: "off", "opf", "obf", or "opff"'
)
parser.add_argument('--import', dest='do_import', action='store_true', 
    help='Actually import products (process is a dry run if missing)')
args = parser.parse_args()


# read limit from args
limit = args.limit

# Check if there is data to read (from file or stdin), else print help and exit
if not args.csv_file and sys.stdin.isatty():
    parser.print_help()
    sys.exit(1)

# If environment is "net", ensure flavor is not "opf", "obf", or "opff"
if args.environment == 'net' and args.flavor in ['opf', 'obf', 'opff']:
    print('Error: "opf", "obf", and "opff" flavors are not supported with "net" default environment.')
    print('Please try "-?" for help.' )
    sys.exit(1)

# Read CSV file from stdin or file argument
def read_products_from_csv(file):
    reader = csv.DictReader(file)
    products = []
    for row in reader:
        if "code" not in row or not row["code"]:
            continue  # skip rows without code
        products.append(row)
    return products

# Get CSV file from argument or stdin
if args.csv_file:
    with open(args.csv_file, newline='', encoding='utf-8') as f:
        products = read_products_from_csv(f)
else:
    products = read_products_from_csv(sys.stdin)

# Apply limit if specified
products_to_import = products[:limit] if limit else products

# Read username and password from config.ini
config = configparser.ConfigParser()
config.read('config.ini')
username = config.get('auth', 'username', fallback=None)
password = config.get('auth', 'password', fallback=None)


api = API(
    user_agent="import_from_csv_script - {username}",
    username=username,
    password=password,
    country=getattr(Country, args.country),
    flavor=getattr(Flavor, args.flavor),
    version=APIVersion.v2,
    environment=getattr(Environment, args.environment),
)

#print(api.__dict__)

#print(f"Importing products to https://{api.APIConfig.get_base_domain}.openfoodfacts.org/api/v2/product/") if products_to_import else print("No products to import.")

if not args.do_import:
    print(f"Dry run: use --import flag to actually import products. (Script: {os.path.basename(sys.argv[0])})")
    print(f"{products_to_import}")
    # Print products as CSV data, limited by --limit flag if provided
    if products_to_import:
        fieldnames = products_to_import[0].keys()
        writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames)
        writer.writeheader()
        for product in itertools.islice(products_to_import, limit):
            writer.writerow(product)
    sys.exit(0)

# Import products to OpenFoodFacts if there are products to import and 
# --import flag is set from command line
if products_to_import and args.do_import:
    for product in products_to_import:
        print(f"Importing product: {product}")
        response = api.product.update(product)
        print(f"Response: {response}")
        if hasattr(response, "status_code") and response.status_code == 200:
            print("Product imported successfully.")
        else:
            print("Failed to import product:", getattr(response, "status_code", None), getattr(response, "text", None))
        time.sleep(1)

