Dev Journey 6: Get ingredient related analysis on new or existing products (presence of palm oil, vegan, veggie, ultra-processed foods, allergens, additives…)

[https://docs.google.com/document/d/1avnxJr8_m6OjRBt0vgwBzlzaZB7Q6z14t0taMKIrkp0/edit](https://docs.google.com/document/d/1avnxJr8_m6OjRBt0vgwBzlzaZB7Q6z14t0taMKIrkp0/edit)

## Benefits
You can get information about absence or unawareness of the presence of:

- **palm oil**: `palm-oil-free`, `palm-oil`, `palm-oil-content-unknown`, `may-contain-palm-oil`
- **vegetarian ingredients**: `vegetarian`, `non-vegetarian`, `vegetarian-status-unknown`, `maybe-vegetarian`.
- **vegan ingredients**: `vegan`, `non-vegan`, `vegan-status-unknown`, `maybe-vegan`.
- level of food processing (Nova)
- allergens
- additives

**Important!** Parsing might not be perfect and the ingredient detection might have issues in some languages. For more information on how you can help improve it, read: [https://github.com/openfoodfacts/openfoodfacts-server/blob/master/taxonomies/ingredients.txt](https://github.com/openfoodfacts/openfoodfacts-server/blob/master/taxonomies/ingredients.txt)


## Introduction {#introduction}

* If you can't get the information on a specific product, you can get your user to send photos and data, that will then be processed by Open Food Facts AI and contributors to get the computed result you want to show them.
* You can implement the complete flow so that they get immediately the result with some effort on their side.
* That will ensure user satisfaction
* Most of the operations described below are implemented in the openfoodfacts-dart plugin, but as individual operations, not as a coherent pipe

![Schema of the ingredients flow](https://docs.google.com/drawings/d/12345/export/png)

## Flow
### The product does not exist
* You can use our [adding products tutorial](./adding-missing-products.md)

### The product does exist: Get the status of the product and show prompts in case of incomplete ingredients or category (also required for NOVA ultra-processing levels)

```
if ( 
status= category-to-be-completed && 
status = ingredients-to-be-completed 
)
then "Add ingredients and a category to see the level of food processing and potential additives"

if ( 
status= category-to-be-completed
)
then "Add a category to see the level of food processing and potential additives"

if ( 
status = ingredients-to-be-completed 
)
then "Add ingredients to see the level of food processing and potential additives"
```

* Once the user has entered once of your completion flow, proceed to the next step

### Upload ingredient photo
* [Please follow our dedicated tutorial on photo upload](../tutorial-uploading-photo-to-a-product.md)
* The DART SDK is offering support for photo upload, and we encourage you to implement it in one of the official Open Food Facts SDKs if it's not supported yet.
* Ensure that your users crop language by language, or take all languages at once, but you perform server side cropping on one specific language before performing the OCR
* We're working on a ML solution to detect languages and performing auto-crops per language ([reuse@openfoodfacts.org](mailto:reuse@openfoodfacts.org) to learn more)
* If you want to skip the next step, try to get rotation, cropping right at this stage

### Adjusting the photo (Selecting, Rotating and Cropping)

* Selecting, cropping and rotating photos are non-destructive actions. That means, the original version of the image uploaded to the system is kept as is. The subsequent changes made to the image are also stored as versions of the original image.

* The actions described in this topic do not modify the image, but provide metadata on how to use it (the data of the corners in the case of selection and the data of the rotation). That is, you send an image to the API, provide an id, you define, for example, the cropping and rotation parameters and as a response, the server generates a new image as requested and you can call this new version of the image.

#### Selecting photos

* [Please look at the specific tutorial](../tutorial-uploading-photo-to-a-product.md)

#### Rotating a photo

* [Please look at the reference](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#get-/cgi/product_image_crop.pl)

#### Cropping Photos

**Note**: Cropping is only relevant for editing already selected images. You need to upload it first to the system, select it, retrieve its id, and then crop it.
This is a non destructive crop. If there's an issue with the image, you should report it using the dedicated NutriPatrol API. 
Moderators will either perform a destructive crop, or more likely delete the image.
* [Please look at the reference](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#post-/cgi/product_image_crop.pl)

#### Unselecting photos

* [Please look at the reference](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#post-/cgi/product_image_unselect.pl)

### Get the Optical Character Recognition (OCR) output of the ingredients photo

Open Food Facts uses optical character recognition (OCR) to retrieve ingredient data and other information (using Robotoff) from the photos of the product labels.
**Notes**:
* The OCR may contain errors. Encourage your users to correct the output using the ingredients WRITE API.
* You can also use your own on-device OCR, especially if you're superconfident about it performing better than the server's cloudvision and if you plan to send a high number of queries.
* Please DO NOT translate and send us the OCR output. We want to store only actual data. If you want translated version of the ingredient list, please send us an email to reuse@openfoodfacts.org

#### API solution

* [Please look at the reference](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#get-/cgi/ingredients.pl)

#### Dart SDK solution

* [https://openfoodfacts.github.io/openfoodfacts-dart/model_OcrIngredientsResult/OcrIngredientsResult-class.html](https://openfoodfacts.github.io/openfoodfacts-dart/model_OcrIngredientsResult/OcrIngredientsResult-class.html) 
* [https://openfoodfacts.github.io/openfoodfacts-dart/utils_OcrField/OcrField-class.html](https://openfoodfacts.github.io/openfoodfacts-dart/utils_OcrField/OcrField-class.html)
* [https://openfoodfacts.github.io/openfoodfacts-dart/utils_OcrField/OcrFieldExtension.html](https://openfoodfacts.github.io/openfoodfacts-dart/utils_OcrField/OcrFieldExtension.html)


### Present the result of the Optical Character Recognition (OCR) output to your user for human review

* Create a UI that encourages careful review, and encourages dropping the output if it's not right
* Create a UI that encourages taking a less blurry, better framed photo to fix the output
* Create a UI that handles multilinguism well

### Send the ingredients

* [Please look at the reference located](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#post-/cgi/product_jqm2.pl)

### Refresh product to display the result to your user

* [Please look at the reference](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v3/#get-/api/v3/product/-barcode-)
![alt_text](images/image1.png "image_tooltip")

