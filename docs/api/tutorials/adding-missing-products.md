# Adding missing products

**Dave** regularly adds new products to the database and completes missing information via API calls. He has described the process below to show other developers how easy it is to contribute.

Note: we have SDKs to simplify product addition (Javascript, Dart, Javascript…). Using them ensure you follow best practises.

---

## Authentication and Header

If you have an app that makes POST calls and you don't want your users to authenticate in Open Food Facts, you can create a global account. Dave has created a global account for the app he is developing with the following credentials:

- `user_id`: myappname
- `password`: 123456

* For a complete reference on AUTH, please read: [Authentication in our introduction](../index.md#authentication)

---

## Adding images to support your edit, and get machine learning predictions
If you ask your users just one thing, it would be to send photos of the packaging (front, ingredients, nutrition, recycling, the more the better)
Please refer to our [comprehensive tutorial on uploading images](../tutorial-uploading-photo-to-a-product.md)

---

## Sending the right country and language parameters, based on the country your user is located in, and the language the product is in.

Traditionnaly, we advised to define the subdomain for the query as `us`. The subdomain automatically defines the country code (`cc`) and language of the interface (`lc`). The country code determines that only the products sold in the US are displayed. The language of the interface for the country code US is English.
In this case:
[https://us.openfoodfacts.org/cgi/product_jqm2.pl?​​​​​​​](https://us.openfoodfacts.org/cgi/product_jqm2.pl?​​​​​​​)

We now advise to pass the `cc` and `lc` parameters within the query, and to limit assumptions as much as you can, especially in bilingual countries (e.g. Belgium, the United States…) but also other countries (some products can be imported).
Ideally, your UI or some heuristic (traditional or using ML) on your side should determine which language(s) the data you send is in (e.g. for multilingual products, send the French ingredient list as a French ingredient list).
We perform OCR on incoming images (even non selected ones), and make the JSON available immediately, so you can either leverage that (you upload the image, and then you select them in a second step, based on the OCR output from the Open Food Facts image server), or use on device ML to determine the proper language to send the call in.

[New documentation for cc and lc parameters​​​​​​​](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#cmp--parameters-cc)

[Sample image](https://images.openfoodfacts.org/images/products/26073347/2.jpg) and [sample JSON](https://images.openfoodfacts.org/images/products/26073347/2.json) you can base your heuristic on.

---

## Product Barcode

Identify the product using the `code` field in the POST request body. The examples below use barcode `0074570036004`. Replace this value with the barcode of the product you want to add or update on the staging server.

---

## Credentials

Send your Open Food Facts username and password as the `user_id` and `password` fields in the POST request body. Keep credentials out of the request URL.

The example in the next section shows how to send these fields with curl.

---

## Parameters

This example adds a brand and a label using `add_brands` and `add_labels`, preserving existing values.

Use the staging server for testing. You need an account registered on https://world.openfoodfacts.net. Replace `YOUR_USERNAME` and `YOUR_PASSWORD` with that account's credentials, and update the example User-Agent with your app's name, version, and contact email.

The `--user off:off` option supplies the staging server's HTTP Basic authentication. This is separate from your Open Food Facts account credentials.

Run this command in a Bash-compatible terminal:

```bash
curl --request POST 'https://world.openfoodfacts.net/cgi/product_jqm2.pl' \
  --user 'off:off' \
  --user-agent 'MyApp/1.0 (myapp@example.com)' \
  --data-urlencode 'user_id=YOUR_USERNAME' \
  --data-urlencode 'password=YOUR_PASSWORD' \
  --data-urlencode 'code=0074570036004' \
  --data-urlencode 'cc=us' \
  --data-urlencode 'lc=en' \
  --data-urlencode 'add_brands=Häagen-Dazs' \
  --data-urlencode 'add_labels=kosher'
```

The `--data-urlencode` options send the fields in the POST request body and encode special characters.

Use `brands` or `labels` only when you intend to replace the existing values and have retrieved and reviewed the complete list.

---

## Adding Additional Information to Existing Fields

For list fields such as brands, labels, and categories, use the supported `add_` parameter to append values while preserving existing entries.

For example, this request adds `Desserts` to the product's categories. Use the same staging credentials and User-Agent described above.

```bash
curl --request POST 'https://world.openfoodfacts.net/cgi/product_jqm2.pl' \
  --user 'off:off' \
  --user-agent 'MyApp/1.0 (myapp@example.com)' \
  --data-urlencode 'user_id=YOUR_USERNAME' \
  --data-urlencode 'password=YOUR_PASSWORD' \
  --data-urlencode 'code=0074570036004' \
  --data-urlencode 'cc=us' \
  --data-urlencode 'lc=en' \
  --data-urlencode 'add_categories=Desserts'
```

Using `categories` instead of `add_categories` replaces the existing category list with the values you submit.

---

## Adding a Comment to your WRITE request.

Use the `comment` parameter to add the id of the user editing the product. The id should not contain any personal data.

**Important!** The user id is not the identifier of an Open Food facts user, but the id generated by your system.

It should be structured as: user-agent + user-id.

**Example**

`comment=Edit by a Healthy Choices 1.2 iOS user - SxGFRZkFwdytsK2NYaDg4MzRVenNvUEI4LzU2a2JWK05LZkFRSWc9PQ`

---
## Leveraging Robotoff ML predictions to simplify life for your users

Leveraging [Robotoff prediction](../intro-robotoff.md) to simplify life for your users.
You can get a category prediction from images (useful for Nutri-Score and Eco-Score), you can get quality labels prediction, brand predictions, weight predictions from images. You can also get an automatic extraction of ingredients and nutrition facts from an image.
To achieve this you need the upload image section above. Adding data like product name, ingredients and nutrition can help, but some predictions can be done with just images.

## Getting your users to check ingredients OCR in an autonomous fashion
Getting your users to [check ingredients OCR in an autonomous fashion](./get-ingredient-related-analysis.md)

## Getting your users to input nutrition facts
[Getting your users to input nutrition facts](../../dev/explain-nutrition-data.md)

## Getting your users to input packaging data
Getting your users to [input packaging data](../../dev/explain-packaging-data.md)

## Showing the result of their work
- You can then reload the product, potentially using Knowledge Panels, to show the rewarding result of their work.
- Make sure to congratulate them each time for their contribution to Open Food Facts and the common good.
