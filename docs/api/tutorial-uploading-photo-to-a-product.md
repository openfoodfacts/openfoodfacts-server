# Tutorial on uploading images to the Open Food Facts API

This basic tutorial shows you how to upload an image of a product to the Open Food Facts API.

Be sure to also read the [introduction to the API](./index.md)

## Points to consider before uploading photos

### Image license

Product images must be under the [Creative Commons Attribution ShareAlike licence](https://creativecommons.org/licenses/by-sa/3.0/deed.en).

That means you should either upload:

- photos that are your own work
- photos taken by your users, with their consent for this license (should be part of your service terms)
- photos already under this license or a compatible license ([cc-by](https://creativecommons.org/licenses/by/4.0/), [cc-0](https://creativecommons.org/share-your-work/public-domain/cc0/) or public domain)

### Image Quality

Uploading quality photos of a product, its ingredients, and the nutrition table is essential because it enables the Open Food Facts OCR system to retrieve important data to analyze the product. The minimal allowed size for photos is 640 x 160 px.

### Upload Behavior

In case you upload more than one photo of the front, the ingredients, the nutrition facts, or the product packaging components, beware that only the latest "selected" photo of each category will be displayed on the product page on the website and on the mobile application.
The older ones are saved and can be "selected" by an API call or via the editing interface (website and mobile application).
You can also upload some photos that are neither of that 4 categories, but they will not be displayed by default. However, all photos will be saved.

### Label Languages

Multilingual products have several photos based on the languages present on the packaging. You can specify the language by adding a lang code suffix to the [image field]((#imagefield)).

## Authentication

The WRITE operations in the OFF API require authentication. Therefore you need a valid `user_id` and `password` to write the photo to 100% Real Orange Juice.

> Sign up on the [Open Food Facts App](https://world.openfoodfacts.net/) to get your `user_id` and `password` if you dont have one. For more details, visit the [Open Food Facts Authentication](https://openfoodfacts.github.io/openfoodfacts-server/introduction/api/#authentication).

## Parameters

### Code

The barcode of the product.

### Imagefield

`imagefield` indicates the type of image you are trying to upload for a particular product. It can be either of these: `front`, `ingredients`, `nutrition`, `packaging` or `other`. You can also specify the language in that image by adding a suffix of the language code to the `imagefield` value. For example — `front_en`, `packaging_fr`.

### ImageUpload

`imageupload` must contain the binary content of the image. This field name is dependent on the  `imagefield`.  It must be `imgupload_` suffixed by the value of the `imagefield` stated earlier. Here are some examples:

- imgupload_front (if imagefield=front)
- imgupload_ingredients_fr (if imagefield=ingredients_fr)
- imgupload_nutrition (if imagefield=nutrition)
- imgupload_packaging (if imagefield=packaging)

### Describing the Post Request

To upload photos to a product, make a `POST` request to the [`Add a Photo to an Existing Product`](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#post-/cgi/product_image_upload.pl) endpoint.

```text
https://world.openfoodfacts.net/cgi/product_image_upload.pl
```

### Upload Photo of a Product

Add a `user_id` and `password` as body parameters to the request for authentication. The `code` (barcode of the product to be updated) is required to indicate the product for the uploaded photo. Then, include other product data to be added in the request body.

To add a new image for ingredients in English  to *100% Real Orange Juice*, the request body should contain these fields :

| Key        | Value           | Description  |
| ------------- |:-------------:| -----:|
| user_id     | *** | A valid user_id |
| password      | ***     |   A valid password |
| code | 0180411000803      |    The barcode of the product to be added/edited |
| imagefield | ingredients_en      |    The type of image to be uploaded|
| imgupload_ingredients_en | file     |   The binary content of the image of the product ingredients in English |

If the image is in the `images/real-orange-juice-ingredients.jpg`, we can use curl (thanks to the special '@' attributes, which enables reading from a file):

```bash
curl -XPOST https://world.openfoodfacts.net/cgi/product_image_upload.pl \
  -F user_id=your_user_id -F password=your_password \
  -F code=0180411000803 -F imagefield=ingredients_en -F imgupload_ingredients_en=@images/real-orange-juice-ingredients.jpg
```

If the request is successful, it returns a response that indicates that the fields have been saved.
You will also get the new image id in `imgid`.

```json
{
  "files": [
    {
      "url": "/product/0180411000803/100%-real-orange-juice",
      "filename": "",
      "name": "100% Real Orange Juice",
      "thumbnailUrl": "/images/products/018/041/100/0803.jpg",
      "code": "0180411000803"
    }
  ],
  "image": {
    "thumb_url": "123.100.jpg",
    "imgid": 123,
    "crop_url": "123.400.jpg"
  },
  "imgid": 123,
  "status": "status ok",
  "imagefield": "ingredients_en",
  "code": "0180411000803"
}
```

If the request is unsuccessful, the response returns `"status": "status not ok"` and an explanation in `debug` field.
