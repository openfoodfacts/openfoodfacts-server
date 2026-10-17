# Adding missing products
Dave regularly adds new products to the database and completes missing information via API calls. He has described the process below to show other developers how easy it is to contribute.
Open Food Facts also provides SDKs that can simplify integration and help applications follow best practices. For new product-write integrations, consult the API v3 reference.
---
## Authentication and headers
Product write requests require an Open Food Facts account. An application may use its own account where appropriate, but credentials must not be hard-coded in source control or included in request URLs.
The examples below target the staging server, `https://world.openfoodfacts.net`, and use a staging account. Staging HTTP Basic Authentication (`off:off`) is separate from the Open Food Facts account credentials submitted in the JSON body. For production integrations and other authentication options, see Authentication in the API introduction and the API v3 reference.
Include an informative User-Agent identifying your application and a contact method. Replace the example User-Agent with your own application's details.
---
## Adding images to support your edit, and get machine learning predictions
If you ask your users just one thing, it would be to send photos of the packaging (front, ingredients, nutrition, recycling—the more the better).
Please refer to our comprehensive tutorial on uploading images.
---
## Country and language
Pass the country context (`cc`) and interface language (`lc`) explicitly where appropriate rather than relying on a country-specific subdomain. Do not infer a product's language solely from the user's country: packaging may be multilingual or imported.
When providing localized product information, use the correct language for each field. Open Food Facts performs OCR on uploaded images and makes results available for applications to inspect.
See the API v3 reference for supported parameters and fields.
Sample image and sample JSON can help when building language-detection logic.
---
## Product barcode
API v3 identifies a product by barcode in the URL: `PATCH /api/v3/product/{code}`. Unlike the legacy `cgi/product_jqm2.pl` form submission, the barcode is not supplied as a `code` form field in the example below.
The examples use barcode `0074570036004` on staging. Replace it with the barcode of the product you intend to add or update. Test against staging first, not production.
---
Credentials for staging examples
Register a staging account at https://world.openfoodfacts.net. In a Bash-compatible terminal, securely enter its password without displaying it or embedding it in the command:
```bash
read -r -s -p "Open Food Facts staging password: " OFF_TEST_PASSWORD
echo
export OFF_TEST_PASSWORD
```
The Python script below reads the password from `OFF_TEST_PASSWORD`. Replace `YOUR_STAGING_USERNAME` with your staging username. Never commit actual credentials to GitHub or paste them into shared logs.
The `--user 'off:off'` curl argument authenticates to the staging site's HTTP Basic access layer. It is not a replacement for the user's Open Food Facts staging account credentials.
---
Adding a category through API v3
Send a `PATCH` request with `Content-Type: application/json` and a `product` object. Use `categories_tags_add` to append a category without replacing existing categories. This differs from the legacy `add_categories` form parameter.
The following example adds `en:desserts` to a staging product. It was tested against staging using an Open Food Facts staging account, followed by a read-back GET request.
```bash
python3 - <<'PY' | curl --silent --show-error --max-time 30 \
  --user 'off:off' \
  --user-agent 'MyApp/1.0 (myapp@example.com)' \
  --request PATCH \
  'https://world.openfoodfacts.net/api/v3/product/0074570036004' \
  --header 'Content-Type: application/json' \
  --data-binary @- \
  | python3 -m json.tool
import json
import os

print(json.dumps({
    "user_id": "YOUR_STAGING_USERNAME",
    "password": os.environ["OFF_TEST_PASSWORD"],
    "lc": "en",
    "cc": "us",
    "product": {
        "categories_tags_add": ["en:desserts"]
    }
}))
PY
```
Check the JSON response for `"status": "success"`, an empty `errors` array, and updated category values. A successful response should be followed by an independent read-back request.
Note: This example demonstrates adding categories. Do not assume that all legacy parameters, including `add_brands` and `add_labels`, have identical API v3 equivalents. Check the API v3 reference for field-specific support.
---
Verify the saved change
Retrieve only the product fields needed for verification:
```bash
curl --silent --show-error \
  --user 'off:off' \
  --user-agent 'MyApp/1.0 (myapp@example.com)' \
  'https://world.openfoodfacts.net/api/v3/product/0074570036004?fields=code,product_name,categories_tags' \
  | python3 -m json.tool
```
Verify the correct barcode and product name, confirm `en:desserts` appears in `product.categories_tags`, and check that previously existing categories remain. This GET verification was performed after the PATCH test on staging.
---
## Handling errors
A deliberately incomplete API v3 PATCH request without the required `product` object returned `"status": "failure"` with a `missing_field` error for `product` during staging testing.
If a request fails, inspect the `status`, `errors`, and `warnings` fields. Also check the staging account username and password, the JSON structure, the barcode, and the supported API v3 field names. Do not treat an HTTP response alone as evidence that an edit was saved.
---
## Adding a comment to a write request
Avoid personal or sensitive data in edit comments. Refer to the API v3 reference for currently supported comment fields and formats rather than automatically reusing legacy write parameters.
---

## Leveraging Robotoff ML predictions to simplify life for your users

Leverage [Robotoff predictions](../intro-robotoff.md) to simplify life for your users.

You can get category, quality label, brand, and weight predictions from images. You can also get automatic extraction of ingredients and nutrition facts.

Refer to the image-upload section above. Adding product names, ingredients, and nutrition information can help, but some predictions can be made using images alone.

## Getting your users to check ingredients OCR in an autonomous fashion

Learn how to [check ingredients OCR autonomously](./get-ingredient-related-analysis.md).

## Getting your users to input nutrition facts

See [Getting your users to input nutrition facts](../../dev/explain-nutrition-data.md).

## Getting your users to input packaging data

See [Getting your users to input packaging data](../../dev/explain-packaging-data.md).

## Showing the result of their work

- Reload the product, potentially using Knowledge Panels, to show users the results of their contributions.
- Congratulate users each time they contribute to Open Food Facts and the common good.
