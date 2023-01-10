# Uploading Images to the OFF API
<!--Add a brief introduction of what the tutorial does -->

This basic tutorial shows you can upload image of a product to the Open Food Facts API.

## Points to consider before uploading photos

### Image license

Products images MUST be under the [Creative Commons Attribution ShareAlike licence](https://creativecommons.org/licenses/by-sa/3.0/deed.en)(https://creativecommons.org/licenses/by-sa/3.0/deed.en).

That means you should either upload: 
* photos that are your own work
* photos taken by your users, with their consent for this license (should be part of your service terms)
* photos already under this license or a more liberal one

### Image Quality

Uploading quality photos of a product, its ingredients and nutrition table is very important, since it allows the Open Food Facts OCR system to retrieve important data to analyze the product. The minimal allowed size for photos is 640 x 160 px.

### Upload Behavior

In case you upload more than one photo of the front, the ingredients and the nutrition facts, beware that only the first photo of each category will be displayed. (You might want to take additional images of labels, recycling instructions, and so on). However, all photos will be saved.

### Label Languages

Multilingual products have several photos based on languages present on the packaging. You can specify the language by adding a lang code suffix to the image field.

See [the paragraph about Imagefield](#imagefield)

## Authentication

The WRITE operations in the OFF API require authentication, therefore you need a valid `user_id` and `password`  to write the photo to 100% Real Orange Juice.

> Sign up on the [Open Food Facts App](https://world.openfoodfacts.net/), to get your `user_id` and `password` if you dont have.
For more details, visit the [Open Food Facts Authentication](https://openfoodfacts.github.io/openfoodfacts-server/introduction/api/#authentication).

## Parameters

### Code

The barcode of the product.

### Imagefield

`imagefield` indicates the type of the image you are trying to upload for a particular product. It can be either of these: `front`, `ingredients`, `nutrition`, `packaging` or `other`.
You can also specify the language present in that image by adding a suffix of the languade code to the `imagefield` value. For example — `front_en`, `packaging_fr`.

### ImageUpload

This is the field that must contains the binary content of the image.

The field name is dependent on  `imagefield`. It must be `imgupload_` suffixed by the value of the `imagefield` stated earlier.

- imgupload_front (if imagefield=front)
- imgupload_ingredients_fr (if imagefield=ingredients_fr)
- imgupload_nutrition (if imagefield=nutrition)
- imgupload_packaging (if imagefield=packaging)

### Describing the Post Request

To upload photos to a product, make a `POST` request to the [`Add a Photo to an Existing Product`](https://openfoodfacts.github.io/openfoodfacts-server/reference/api/#tag/Write-Requests/operation/get-cgi-product_image_upload.pl) endpoint.

```text
https://off:off@world.openfoodfacts.net/cgi/product_image_upload.pl
```

### Upload Photo of a Product

For authentication, add your valid `user_id` and `password` as body parameters to your request. The `code` (barcode of the product to be updated), `user_id` and `password` are required fields when adding or editing a product. Then, include other product data to be added in the request body.

To write `ingredients_en` to 100% Real Orange Juice so that the image can be uploaded, the request body should contain these fields :

| Key        | Value           | Description  |
| ------------- |:-------------:| -----:|
| user_id     | *** | A valid user_id |
| password      | ***     |   A valid password |
| code | 0180411000803      |    The barcode of the product to be added/edited |
| imagefield | ingredients_en      |    The type of image to be uploaded|
| imageupload_ingredients_en | file     |   The  image of the product ingredients in english |

Using curl:

```bash
curl -XPOST -u off:off -x POST https://world.openfoodfacts.net/cgi/product_jqm2.pl \
  -F user_id=your_user_id -F password=your_password \
  -F code=0180411000803 -F imagefield=ingredients_en -F imageupload_ingredients_en=<binary>"
```

If the request is successful, it returns a response that indicates that the fields have been saved.

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
