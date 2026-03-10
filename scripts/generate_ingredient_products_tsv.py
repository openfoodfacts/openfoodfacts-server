"""
Creates an "ingredient" products TSV file that can be loaded into the producers platform
and then exported to the main database

This script uses uv to load dependencies. To install uv run:

curl -LsSf https://astral.sh/uv/install.sh | sh

To run the script use:

uv run scripts/generate_ingredient_products_tsv.py


scripts/export_and_import_to_public_database.pl --owner org-openfoodfacts

TODO:
* Find a way to show there is no packaging
* en:nutrition-sugars-plus-starch-greater-than-carbohydrates
* en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients. e.g. radish

"""

# /// script
# dependencies = [
#   'requests',
#   'dotenv'
# ]
# ///

import csv
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
countries = ",".join(
    requests.get(f"{base_url}/data/taxonomies/countries.json").json().keys()
)
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
        print(
            f"*** Error: {', '.join(error.get('message', {}).get('name', '?') for error in response.json().get('errors', []))} ***"
        )
    except json.JSONDecodeError:
        print(f"*** Error: {response.content} ***")
    return False


print("--- Logging in ---")
# Uses the outward facing url for local development
oidc_discovery_url = os.getenv("OIDC_DISCOVERY_URL").replace(
    "//keycloak:8080/", "//auth.openfoodfacts.localhost:5600/"
)
openid_configuration = requests.get(oidc_discovery_url).json()
token_endpoint = openid_configuration["token_endpoint"]

response = requests.post(
    token_endpoint,
    data={
        "grant_type": "password",
        # Set the following in .envrc to you OFF credentials. Must be a Producer
        "username": os.getenv("OIDC_USERNAME"),
        "password": os.getenv("OIDC_PASSWORD"),
    },
    auth=HTTPBasicAuth(os.getenv("OIDC_CLIENT_ID"), os.getenv("OIDC_CLIENT_SECRET")),
).json()

access_token = response["access_token"]
off_headers = {"Authorization": f"Bearer {access_token}"}

# Get the existing ingredient products so we know which ones already have images
# and which ones to delete (if they weren't found in the current ingredients taxonomy)
print("--- Fetching existing products ---")
page = 1
existing_codes = []
products_with_images = []
while True:
    response = requests.get(
        f"{base_url}/api/v2/search?fields=code,selected_images&owners_tags=org-openfoodfacts&page_size=1000&page={page}",
        headers=off_headers,
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

with open(
    "tmp/generate_ingredient_products_status.tsv", "w", newline="", encoding="utf-8"
) as status_file:
    status_file_writer = csv.writer(status_file, delimiter="\t")
    status_file_writer.writerow(
        [
            "ingredient_id",
            "ciqual_code",
            "has_ciqual_data",
            "category",
            "has_image",
            "wikidata_id",
            "wikidata_found",
            "wikidata_image_count",
            "wikidata_image",
        ]
    )

    count = 0
    # Set the following to zero to delete all ingredient products
    # To then hard-delete the product files and images run the following from a backend shell:
    # rm -rf /mnt/podata/products/ingredient
    # rm /mnt/podata/new_images/*.ingredient-*
    max_count = 10000
    print("--- Creating products ---")
    products = []
    for id in sorted(ingredients):
        if count >= max_count:
            break

        ingredient = ingredients[id]

        # Only import ingredients that have a Ciqual food code (could maybe include proxy)
        ciqual_code = ingredient.get("ciqual_food_code", {}).get("en")
        ciqual_data = None
        if ciqual_code:
            ciqual_data = ciqual_ingredients.get(ciqual_code, {}).get("nutrients")

        # Find a suitable category. First see if there is only one category with this as the expected ingredient
        # If there are more than one, then try to match on CIQUAL code as well.
        # If there is still more than one just use the first.
        matching_categories = {
            k: v
            for (k, v) in categories.items()
            if v.get("expected_ingredients", {}).get("en") == id
        }
        if ciqual_code:
            if len(matching_categories) > 1:
                # More than one match. Try to match on CIQUAL as well
                ciqual_categories = {
                    k: v
                    for (k, v) in matching_categories.items()
                    if v.get("ciqual_food_code", {}).get("en") == ciqual_code
                }
                # If we have one or more with both matching we will take the first
                if len(ciqual_categories) > 0:
                    matching_categories = ciqual_categories
            else:
                # No match by expected ingredients: Just match by ciqual code
                matching_categories = {
                    k: v
                    for (k, v) in categories.items()
                    if v.get("ciqual_food_code", {}).get("en") == ciqual_code
                }

        category = next(iter(matching_categories), None)

        code = f"ingredient-{id.replace(':', '-')}"
        got_image = code in products_with_images
        image_url = ""

        # We only include ingredients that have a Wikidata link with an image bigger than the minimum of 640 x 160
        wikidata_id = ingredient.get("wikidata", {}).get("en")
        wikidata_claim = None
        wikidata_images = []
        if wikidata_id and not got_image:
            # Fetch the images property
            wikidata_url = f"https://www.wikidata.org/w/api.php?action=wbgetclaims&entity={wikidata_id}&property=P18&format=json"
            wikidata_response = requests.get(wikidata_url, headers=wikidata_headers)
            try:
                wikidata_claim = requests.get(
                    wikidata_url, headers=wikidata_headers
                ).json()
            except json.JSONDecodeError:
                pass

            if wikidata_claim:
                wikidata_images = wikidata_claim.get("claims", {}).get("P18", [])
                if len(wikidata_images) < 1:
                    continue

                for image in wikidata_images:
                    image_name = (
                        image.get("mainsnak", {}).get("datavalue", {}).get("value")
                    )
                    if not image_name:
                        continue

                    # Get the image metadata. Minimum size is 640 by 160
                    image_metadata = requests.get(
                        f"https://commons.wikimedia.org/w/api.php?action=query&prop=imageinfo&format=json&iiprop=size&titles=File:{image_name}",
                        headers=wikidata_headers,
                    ).json()
                    pages = image_metadata.get("query", {}).get("pages", {})
                    page = next(iter(pages.values()))
                    imageinfo = next(iter(page.get("imageinfo", [])), None)
                    if imageinfo and (
                        imageinfo["width"] >= 640 or imageinfo["height"] >= 160
                    ):
                        # Get the actual image
                        image_name = image_name.replace(" ", "_")
                        # Hash is just used to generate a path, not for anything secure
                        image_hash = hashlib.md5(  # NOSONAR
                            image_name.encode("utf-8")
                        ).hexdigest()
                        # If the image is bigger than 960px then use a thumbnail
                        if imageinfo["width"] >= 960:
                            image_url = f"https://upload.wikimedia.org/wikipedia/commons/thumb/{image_hash[0]}/{image_hash[0:2]}/{image_name}/960px-{image_name}"
                        else:
                            image_url = f"https://upload.wikimedia.org/wikipedia/commons/{image_hash[0]}/{image_hash[0:2]}/{image_name}"
                        break

        # We only create an ingredient product if we have a ciqual_code, ciqual_data, can find a category
        # and have a wikidata link with a valid image, or already have an image on an existing product
        status_file_writer.writerow(
            [
                id,
                ciqual_code,
                ciqual_data is not None,
                category,
                got_image,
                wikidata_id,
                wikidata_claim is not None,
                len(wikidata_images),
                image_url,
            ]
        )
        if ciqual_data and category and (got_image or image_url):

            # We set all countries so ingredients always show up. Might be nice to get all "world" products to show up on all country domains
            product = {
                "code": code,
                "countries": countries,
                "categories": category,
                "packaging_text_en": "1 paper bag to recycle",
                "image_front_url": image_url.replace(
                    ",", "%2c"
                ),  # Escape commas so PO doesn't think there are multiple files
            }

            # Create a product name for each language
            for lang, name in ingredient["name"].items():
                product[f"product_name_{lang}"] = name
                product[f"ingredients_text_{lang}"] = f"{name} 100%"

            # Add nutrients from ciqual
            for nutrient_id, nutrient in ciqual_data.items():
                if nutrient.get("confidence", "-") != "-":
                    product[f"{nutrient_id}"] = (
                        f"{nutrient.get('modifier', '')}{nutrient.get('percent_nom')}"
                    )

            products.append(product)
            print(
                id,
                ciqual_code,
                wikidata_id,
                ingredient["name"].get("en", name),
                image_url,
            )

            count += 1
            if code in existing_codes:
                existing_codes.remove(code)

print("--- Generating tsv file ---")


def column_sort(column):
    if column == "code":
        return f"1{column}"
    elif column.startswith("categories"):
        return f"2{column}"
    elif column.startswith("image_front_url"):
        return f"3{column}"
    elif column.startswith("packaging"):
        return f"4{column}"
    elif column.startswith("product_name"):
        return f"6{column}"
    elif column.startswith("ingredients_text"):
        return f"7{column}"
    elif column == "countries":
        return f"8{column}"

    # Must be a nutrient
    return f"5{column}"


keys = sorted(set().union(*(d.keys() for d in products)), key=column_sort)
with open(
    "tmp/generate_ingredient_products.tsv", "w", newline="", encoding="utf-8"
) as output_file:
    dict_writer = csv.DictWriter(output_file, keys, delimiter="\t")
    dict_writer.writeheader()
    dict_writer.writerows(products)

print("--- Listing orphaned codes ---")
for code in existing_codes:
    print(code)
