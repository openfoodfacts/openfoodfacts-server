"""
Creates "ingredient" products from the ingredients taxonomy

This script uses uv to load dependencies. To install uv run:

curl -LsSf https://astral.sh/uv/install.sh | sh

To run the script use:

uv run scripts/refresh_ingredient_products.py

TODO:
* Add error handling on requests
* Figure out what's going on with the Kumquat image
* Find a way to show there is no packaging

"""

# /// script
# dependencies = [
#   'requests',
#   'dotenv'
# ]
# ///

import requests
from requests.auth import HTTPBasicAuth
import os
from dotenv import load_dotenv
import hashlib
import base64
import json

load_dotenv(".envrc")
load_dotenv()

print("*** Loading taxonomies ***")
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

print("*** Logging in ***")
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
        # Set the following in .envrc to you OFF credentials. Must be a moderator for deletes
        "username": os.getenv("OIDC_USERNAME"),
        "password": os.getenv("OIDC_PASSWORD"),
    },
    auth=HTTPBasicAuth(os.getenv("OIDC_CLIENT_ID"), os.getenv("OIDC_CLIENT_SECRET")),
)
access_token = response.json()["access_token"]
off_headers = {"Authorization": f"Bearer {access_token}"}

# Wikidata requires a user agent to be specified. See https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_User-Agent_Policy
wikidata_headers = {
    "User-Agent": "OpenFoodFacts/1.0 (https://world.openfoodfacts.org) ingredient-uploader"
}

# Get the existing ingredient products so we know which ones already have images
# and which ones to delete (if they weren't found in the current ingredients taxonomy)
print("*** Fetching existing products ***")
page = 1
existing_codes = []
products_with_images = []
while True:
    existing_products = requests.get(
        f"{base_url}/api/v2/search?fields=code,selected_images&states_tags=en:is-ingredient&page_size=1000&page={page}"
    ).json()
    products = existing_products["products"]
    if len(products) < 1:
        break
    existing_codes += [product["code"] for product in products]
    products_with_images += [
        product["code"] for product in products if "selected_images" in product
    ]
    page += 1

count = 0
# Set the following to zero to delete all ingredient products
# To then hard-delete the product files and images run the following from a backend shell:
# rm -rf /mnt/podata/products/ingredient
# rm /mnt/podata/new_images/*.ingredient-*
max_count = 10
print("*** Creating products ***")
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
    if not got_image:
        # We only include ingredients that have a Wikidata link with an image bigger than the minimum of 640 x 160
        wikidata_id = ingredient.get("wikidata", {}).get("en")
        if not wikidata_id:
            continue

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
                image_url = f"https://upload.wikimedia.org/wikipedia/commons/{image_hash[0]}/{image_hash[0:2]}/{image_name}"
                print(image_url)
                image_content = requests.get(
                    image_url, headers=wikidata_headers
                ).content
                break

        if not image_content:
            continue

    # We set all countries so ingredients always show up. Might be nice to get all "world" products to show up on all country domains
    product = {
        "code": code,
        "countries": countries,
        "categories": category,
        "packaging_text_en": "1 paper bag to recycle",
    }

    # Create a product name for each language
    for lang, name in ingredient["name"].items():
        product[f"product_name_{lang}"] = name
        product[f"ingredients_text_{lang}"] = f"{name} 100%"

    # Add nutrients from ciqual
    for nutrient_id, nutrient in ciqual_data.items():
        if nutrient.get("confidence", "-") != "-":
            product[f"nutriment_{nutrient_id}"] = nutrient.get("percent_nom")

    # Create the product
    requests.post(f"{base_url}/cgi/product_jqm2.pl", data=product, headers=off_headers)
    if not got_image:
        # Add the image
        requests.post(
            f"{base_url}/api/v3/product/{code}/images",
            json={
                "image_data_base64": base64.b64encode(image_content).decode(),
                "selected": {"front": {"en": {}}},
            },
            headers=off_headers,
        )
    print(id, ingredient["name"].get("en", name))
    count += 1
    if code in existing_codes:
        existing_codes.remove(code)

print("*** Deleting orphaned codes ***")
for code in existing_codes:
    requests.post(
        f"{base_url}/cgi/product.pl",
        data={"type": "delete", "action": "process", "code": code},
        headers=off_headers,
    )
    print(code)
