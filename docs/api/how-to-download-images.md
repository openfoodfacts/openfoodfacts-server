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

All images can be found on
[https://images.openfoodfacts.org/images/products/](https://static.openfoodfacts.org/images/products/).
Images of a product are stored in a single directory. The path of this
directory can be inferred easily from the product barcode. If the product
barcode length is lower or equal to 8 (ex: "22222222"), the directory path is
simply the barcode: all images can be found on
`https://images.openfoodfacts.org/images/products/{barcode}`.

Otherwise, the following regex is used to split the barcode into subfolders:
`r"^(...)(...)(...)(.*)$"`. For example, the barcode `3435660768163` is split as
follows: `343/566/076/8163`, and all images of the products can be found on
[https://images.openfoodfacts.org/images/products/343/566/076/8163](https://images.openfoodfacts.org/images/products/343/566/076/8163).

To get the image file names, we have to use the database dump or the API. All
images information are stored in the `images` field. For product
[3168930010883](https://world.openfoodfacts.org/api/v0/product/3168930010883.json),
we have:

```json
    {
      "4": {
        "uploader": "openfoodfacts-contributors",
        "uploaded_t": 1548685211,
        "sizes": {
          "400": {
            "h": 400,
            "w": 300
          },
          "100": {
            "w": 75,
            "h": 100
          },
          "full": {
            "h": 3174,
            "w": 2380
          }
        }
      },
      "3": {
        "uploader": "openfoodfacts-contributors",
        "uploaded_t": 1537002125,
        "sizes": {
          "full": {
            "h": 3302,
            "w": 2476
          },
          "100": {
            "h": 100,
            "w": 75
          },
          "400": {
            "w": 300,
            "h": 400
          }
        }
      },
      "ingredients_fr": {
        "rev": "7",
        "orientation": "0",
        "ocr": 1,
        "imgid": "2",
        "y2": null,
        "white_magic": "0",
        "angle": null,
        "x1": null,
        "x2": null,
        "geometry": "0x0-0-0",
        "normalize": "0",
        "y1": null,
        "sizes": {
          "100": {
            "h": 100,
            "w": 75
          },
          "400": {
            "w": 300,
            "h": 400
          },
          "200": {
            "w": 150,
            "h": 200
          },
          "full": {
            "h": 1200,
            "w": 900
          }
        }
      },
      "nutrition_fr": {
        "sizes": {
          "200": {
            "h": 200,
            "w": 150
          },
          "full": {
            "w": 2476,
            "h": 3302
          },
          "100": {
            "w": 75,
            "h": 100
          },
          "400": {
            "w": 300,
            "h": 400
          }
        },
        "y1": "-1",
        "normalize": null,
        "x2": "-1",
        "geometry": "0x0--8--8",
        "x1": "-1",
        "angle": 0,
        "imgid": "3",
        "white_magic": null,
        "y2": "-1",
        "ocr": 1,
        "orientation": "0",
        "rev": "11"
      },
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
      "2": {
        "sizes": {
          "100": {
            "h": 100,
            "w": 75
          },
          "400": {
            "h": 400,
            "w": 300
          },
          "full": {
            "h": 1200,
            "w": 900
          }
        },
        "uploader": "kiliweb",
        "uploaded_t": "1527184615"
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

-   digits: the image is the raw image sent by the contributor (full resolution).
-   selected images: `front_{lang}`, `nutrition_{lang}` and
    `ingredients_{lang}`, selected as front, nutrition and ingredients images
    respectively for `lang`. Here, `lang` is a 2-letter ISO 639-1 language code
    (fr, en, es,\...).

Each image is available in different resolutions: `100`, `200`, `400` or
`full`, each corresponding to image height (`full` means not resized). The
available resolutions can be found in the `sizes` subfield.

Selected images have additional fields:

-   `rev` (as revision) indicates the revision number of the image to use (each
    time a new image is selected, cropped or rotated, a new image with an
    incremented rev is generated).
-   `imgid`, the image ID of the raw image used to generate the selected image.
-   `angle`, `x1`, `x2`, `y1`, `y2`: rotation angle and cropping coordinates.

For selected images, the file name is the image key followed by the revision
number and the resolution: `front_fr.1.400.jpg`. For raw images, the file name
is either the image ID (`1.jpg`) or the image ID followed by the resolution
(`1.100.jpg`).

To get the full URL, simply concatenate the product directory path and the
image name. Examples:

- [https://images.openfoodfacts.org/images/products/343/566/076/8163/1.jpg](https://images.openfoodfacts.org/images/products/343/566/076/8163/1.jpg)
- [https://images.openfoodfacts.org/images/products/343/566/076/8163/1.400.jpg](https://images.openfoodfacts.org/images/products/343/566/076/8163/1.400.jpg)
