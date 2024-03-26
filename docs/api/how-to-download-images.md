# How to download product images

The preferred method of downloading Open Food Facts images depends on what you
which to achieve.

If you want to download a limited number of images, especially if these images
have been uploaded recently, you should [download the image from Open Food
Facts
server](./how-to-download-images.md#download-from-open-food-facts-server).

If you plan to download a large amount of images, you should on the contrary
[use Open Food Facts images dataset hosted on
AWS](./how-to-download-images.md#download-from-aws).

## Download from AWS

If you want to download a large number of images, this is the recommended
option, as AWS S3 will be faster and allow concurrent download, contrary to
Open Food Facts server, where you should preferably download images one at a
time. See [AWS Images dataset](./aws-images-dataset.md) for more information
about how to download images from AWS dataset.

## Download from Open Food Facts server

All images are hosted under
[https://images.openfoodfacts.org/images/products/](https://static.openfoodfacts.org/images/products/) folder. 
But you have to build the right URL from the product info.

### Computing single product image folder

Images of a product are stored in a single directory. The path of this
directory can be inferred easily from the product barcode.
There are two cases:

1. If the product barcode length is lower or equal to 8 (ex: "22222222"), the directory path is
simply the barcode: `https://images.openfoodfacts.org/images/products/{barcode}`.

2. Otherwise, we split the 9 first part of the code by group of three digits to get the three first folder names, and use the rest of the name as the last folder name^[split-regexp].
   For example, the barcode `3435660768163` is split as : `343/566/076/8163`, thus products images will be in `https://images.openfoodfacts.org/images/products/343/566/076/8163`

^[split-regexp]: The following regex can be used to split the barcode into subfolders: `r"^(...)(...)(...)(.*)$"`

### Computing single image file name

Above we get the folder name, now we need the filename inside that folder for a particular image.

#### Understanding images data

To get the image file names, we have to use the database dump or the API. 
All images information are stored in the `images` field. 

Eg. For product [3168930010883](https://world.openfoodfacts.org/api/v0/product/3168930010883.json),
we have (trimmed the data):

```json
    {
      "1": {
        "sizes": {
          "full": {
            "w": 850,
            "h": 1200
          },
          "100": {
            "h": 100,
            "w": 71
          },
          "400": {
            "h": 400,
            "w": 283
          }
        },
        "uploader": "kiliweb",
        "uploaded_t": "1527184614"
      },
      "front_fr": {
        "x1": null,
        "angle": null,
        "y2": null,
        "white_magic": "0",
        "imgid": "1",
        "rev": "4",
        "sizes": {
          "200": {
            "w": 142,
            "h": 200
          },
          "full": {
            "w": 850,
            "h": 1200
          },
          "400": {
            "h": 400,
            "w": 283
          },
          "100": {
            "w": 71,
            "h": 100
          }
        },
        "y1": null,
        "normalize": "0",
        "geometry": "0x0-0-0",
        "x2": null
      }
    }
```

The keys of the map are the keys of the images. These keys can be:

-   digits: the image is the *raw image* sent by the contributor (full resolution).
-   selected images:
    * `front_{lang}` correspond to the front product image in language with code `lang`
    * `ingredients_{lang}` correspond to the ingredients image in language with code `lang`
    * `nutrition_{lang}` is the same but for nutrition data
    * `packaging_{lang}` for packaging logos

    `lang` is a 2-letter ISO 639-1 language code (fr, en, es, …).

Each image is available in different resolutions: 
`100`, `200`, `400` or `full`, each corresponding to image height (`full` means not resized).
The available resolutions can be found in the `sizes` subfield.

#### Filename for a raw image

For a raw image (the one under a numeric key in images field), 
filename is very easy to compute: 
* just take the image digit + `.jpg` for full resolution
* image digit + `.` + resolution + `.jpg` for a lower resolution

For our example above, the filename for image `"1"`
* in resolution 400px is `1.400.jpg`
* in full resolution, it is `1.jpg`

So, adding the folder part, the final url for our example is: 
* https://images.openfoodfacts.org/images/products/316/893/001/0883/1.jpg for the full image
* https://images.openfoodfacts.org/images/products/316/893/001/0883/1.400.jpg for the 400px version

#### Filename for a selected image

In the structure, selected images have additional fields:

-   `rev` (as revision) indicates the revision number of the image to use (each
    time a new image is selected, cropped or rotated, a new image with an
    incremented rev is generated).
-   `imgid`, the image ID of the raw image used to generate the selected image.
-   `angle`, `x1`, `x2`, `y1`, `y2`: rotation angle and cropping coordinates (it's to be able to regenerate the image from the raw image)

For selected images, the filename is the image key followed by the revision number and the resolution: `<image_name>.<rev>.<resolution>.jpg`.
Resolution must always be specified, but you can use `full` keyword to get the full resolution image.

In our above example, the filename for the front image in french (`front_fr` key) is:
* `front_fr.4.400.jpg` for 400 px version
* `front_fr.4.full.jpg` for full resolution version

So, adding the folder part, the final url for our example is: 
* https://images.openfoodfacts.org/images/products/316/893/001/0883/front_fr.4.full.jpg for the full image
* https://images.openfoodfacts.org/images/products/316/893/001/0883/front_fr.4.400.jpg for the 400px version

## A python snippet

So if we have the product_data in a dict, a Python code doing it would be something like:

```python
def get_image_url(product_data, image_name, resolution="full"):
    if image_name not in product_data["images"]:
        return None
    base_url = "https://images.openfoodfacts.org/images/products"
    # get product folder name
    folder_name = product_data["code"]
    if len(folder_name) > 8:
        folder_name = re.sub(r'(...)(...)(...)(.*)', r'\1/\2/\3/\4', folder_name)
    # get filename
    if re.match("^\d+$", image_name):  # only digits
        # raw image
        resolution_suffix = "" if resolution == "full" else f".{resolution}"
        filename = f"{image_name}{resolution_suffix}.jpg"
    else:
        # selected image
        rev = product_data["images"][image_name]["rev"]
        filename = f"{image_name}.{rev}.{resolution}.jpg"
    # join things together
    return f"{base_url}/{folder_name}/{filename}"
```
        
        
