"""
Creates an "ingredient" products TSV file that can be loaded into the producers platform
and then exported to the main database

This script uses uv to load dependencies. To install uv run:

curl -LsSf https://astral.sh/uv/install.sh | sh

To run the script use:

uv run scripts/generate_ingredient_products_tsv.py

TODO:
* Find a way to show there is no packaging
* Make sure sugars adds up to at least all other parts

"""

# /// script
# dependencies = [
#   'requests',
#   'dotenv'
# ]
# ///

import csv
import datetime
import sys
import requests
from requests.auth import HTTPBasicAuth
import os
from dotenv import load_dotenv
import hashlib
import json

load_dotenv(".envrc")
load_dotenv()

print("--- Loading taxonomies ---")
# For local testing use http:/world.openfoodfacts.localhost
base_url = os.getenv("STATIC_DOMAIN")
ingredients = requests.get(f"{base_url}/data/taxonomies/ingredients.json").json()
categories = requests.get(f"{base_url}/data/taxonomies/categories.json").json()

# Load ciqual ingredients. File comes from https://github.com/openfoodfacts/recipe-estimator/blob/main/recipe_estimator/assets/ciqual_ingredients.json
with open(
    os.path.join(os.path.dirname(__file__), "ciqual_ingredients.json"),
    "r",
    encoding="utf-8",
) as ciqual_file:
    ciqual_ingredients = json.load(ciqual_file)

# Wikidata requires a user agent to be specified. See https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_User-Agent_Policy
wikidata_headers = {
    "User-Agent": "OpenFoodFacts/1.0 (https://world.openfoodfacts.org) ingredient-uploader"
}

def po_response_is_ok(response: requests.Response):
    if response.status_code == 200:
        return True
    try:
        print(f"*** Error: {', '.join(error.get('message', {}).get('name', '?') for error in response.json().get('errors', []))} ***")
    except:
        print(response.content)
    return False

# Get the existing ingredient products so we know which ones already have images
# and which ones to delete (if they weren't found in the current ingredients taxonomy)
print("--- Fetching existing products ---")
page = 1
existing_codes = []
products_with_images = []
while True:
    response = requests.get(
        f"{base_url}/api/v2/search?fields=code,selected_images&owners_tags=org-openfoodfacts&page_size=1000&page={page}"
    )
    if not po_response_is_ok(response):
        sys.exit(1)
    products = response.json()["products"]
    if len(products) < 1:
        break
    existing_codes += [product["code"] for product in products]
    products_with_images += [
        product["code"] for product in products if "selected_images" in product
    ]
    print(f"Fetched: {len(existing_codes)}")
    page += 1

count = 0
# Set the following to zero to delete all ingredient products
# To then hard-delete the product files and images run the following from a backend shell:
# rm -rf /mnt/podata/products/ingredient
# rm /mnt/podata/new_images/*.ingredient-*
max_count = 100
print("--- Creating products ---")
products = []
for id, ingredient in ingredients.items():
    if count >= max_count:
        break

    # Only import ingredients that have a Ciqual food code (could maybe include proxy)
    ciqual_code = ingredient.get("ciqual_food_code", {}).get("en")
    if not ciqual_code:
        continue
    ciqual_data = ciqual_ingredients.get(ciqual_code, {}).get("nutrients")
    if not ciqual_data:
        continue

    # Find a category with a matching ciqual code
    category = next(
        (category_id
            for category_id, category_data in categories.items()
            if category_data.get("ciqual_food_code", {}).get("en") == ciqual_code
        ),
        None,
    )
    if not category:
        continue

    code = f"ingredient-{id.replace(':', '-')}"
    got_image = code in products_with_images
    # We only include ingredients that have a Wikidata link with an image bigger than the minimum of 640 x 160
    wikidata_id = ingredient.get("wikidata", {}).get("en")
    if not wikidata_id:
        continue

    image_url = ""
    if not got_image:
        # Fetch the images property
        wikidata_url = f"https://www.wikidata.org/w/api.php?action=wbgetclaims&entity={wikidata_id}&property=P18&format=json"
        wikidata_claim = requests.get(wikidata_url, headers=wikidata_headers).json()
        images = wikidata_claim.get("claims", {}).get("P18", [])
        if len(images) < 1:
            continue

        for image in images:
            image_name = image.get("mainsnak", {}).get("datavalue", {}).get("value")
            if not image_name:
                continue

            # Get the image metadata. Minimum size is 640 by 160
            image_metadata = requests.get(
                f"https://commons.wikimedia.org/w/api.php?action=query&prop=imageinfo&format=json&iiprop=size&titles=File:{image_name}",
                headers=wikidata_headers,
            ).json()
            pages = image_metadata.get("query", {}).get("pages", {})
            page = next(iter(pages.values()))
            imageinfo = page.get("imageinfo", [])[0]
            if imageinfo and (imageinfo["width"] >= 640 or imageinfo["height"] >= 160):
                # Get the actual image
                image_name = image_name.replace(" ", "_")
                # Hash is just used to generate a path, not for anything secure
                image_hash = hashlib.md5(image_name.encode("utf-8")).hexdigest() # NOSONAR
                # If the image is bigger than 960px then use a thumbnail
                if imageinfo["width"] >= 960:
                    image_url = f"https://upload.wikimedia.org/wikipedia/commons/thumb/{image_hash[0]}/{image_hash[0:2]}/{image_name}/960px-{image_name}"
                else:
                    image_url = f"https://upload.wikimedia.org/wikipedia/commons/{image_hash[0]}/{image_hash[0:2]}/{image_name}"
                break

        if not image_url:
            continue

    # We set all countries so ingredients always show up. Might be nice to get all "world" products to show up on all country domains
    product = {
        "code": code,
        "countries": "en:world",
        "categories": category,
        "packaging_text_en": "1 paper bag to recycle",
        "image_front_url": image_url
    }

    # Create a product name for each language
    for lang, name in ingredient["name"].items():
        product[f"product_name_{lang}"] = name
        product[f"ingredients_text_{lang}"] = f"{name} 100%"

    # Add nutrients from ciqual
    for nutrient_id, nutrient in ciqual_data.items():
        if nutrient.get("confidence", "-") != "-":
            product[f"{nutrient_id}"] = nutrient.get("percent_nom")

    products.append(product)
    print(id, ciqual_code, wikidata_id, ingredient["name"].get("en", name), image_url)

    count += 1
    if code in existing_codes:
        existing_codes.remove(code)

print("--- Generating tsv file ---")
keys = sorted(set().union(*(d.keys() for d in products)))
with open('generate_ingredient_products.tsv', 'w', newline='', encoding='utf-8') as output_file:
    dict_writer = csv.DictWriter(output_file, keys, delimiter='\t')
    dict_writer.writeheader()
    dict_writer.writerows(products)

print("--- Listing orphaned codes ---")
for code in existing_codes:
    print(code)
