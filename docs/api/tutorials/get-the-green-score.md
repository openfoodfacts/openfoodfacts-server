Helping your users get the Green-Score for any product

- If you can't get the information on a specific product, you can get your user to send photos and data.
- That will then be processed by Open Food Facts to get the computed result you want to show them.
- You can implement the complete flow so that they get immediately the result with some effort on their side.
- That will ensure user satisfaction
- Please refer to the [product addition tutorial](./adding-missing-products.md) for the technical way to do the required operations (such as category input), and to the high level workflow below for all the cases you have to handle.

## Table of contents

* Getting your app ready for the Green-Score
* Implementing the basic display of the score
* Displaying the Green-Score outside France
* Ensuring a good user experience (even with data gaps)
* Adding disclaimers when we can't display the Green-Score
* Adding disclaimers when the Green-Score is computed with a data gap + Asking the users to photograph and/or complete missing information
* Adding value by explaining
* Product Attributes
* Additional ways to get ready
* Onboarding producers you know

### Implementing the basic display of the score

#### Preferred method : Knowledge panels
* With Knowledge panels, you just have to implement a for-loop in your app. Translations, updates, and all the complexity will be handled 


#### Using the Raw API
* The API is adding a new ecoscore_grade field from A to E. Technically wise, it behaves like the Nutri-Score, so you can clone part of your Nutri-Score implementation 
* If (and only if) the server sends back a proper value (a, b, c, d or e), display the new score, otherwise, display our gray placeholder
* [https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade](https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade)
* {"status_verbose":"product found","product":{"ecoscore_grade":"b"},"status":1,"code":"3414280980209"}
* https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade
* Here are the visuals.
    * [https://static.openfoodfacts.org/images/icons/ecoscore-a.svg](https://static.openfoodfacts.org/images/icons/ecoscore-a.svg)
    * [https://static.openfoodfacts.org/images/icons/ecoscore-b.svg](https://static.openfoodfacts.org/images/icons/ecoscore-b.svg)
    * [https://static.openfoodfacts.org/images/icons/ecoscore-c.svg](https://static.openfoodfacts.org/images/icons/ecoscore-c.svg)
    * [https://static.openfoodfacts.org/images/icons/ecoscore-d.svg](https://static.openfoodfacts.org/images/icons/ecoscore-d.svg)
    * [https://static.openfoodfacts.org/images/icons/ecoscore-e.svg](https://static.openfoodfacts.org/images/icons/ecoscore-e.svg)
    * [https://static.openfoodfacts.org/images/icons/ecoscore-unknown.svg](https://static.openfoodfacts.org/images/icons/ecoscore-unknown.svg) 


#### Using the Attributes API

The Open Food Facts official app use this one, which is less work but also less flexible (will display other data as well).


### Displaying the Green-Score outside France
* You need to ensure the country your users are in:
    * Asking them explicitly at startup, and storing the value
    * Geofencing your app to just one country
    * Using the phones or the IP address (using eg GeoIP) to infer a country
* You need to serve the matching Green-Score value
    * You can ask for a country specific Green-Score
* **If your users are outside France, you need to clearly display the experimental disclaimer at least once.**


### Ensuring a good user experience (even with data gaps)

_We can compute the Green-Score for most of the database, but we’re missing some data on some products to make the computation exact, and it won’t be computed on some products. <span style="text-decoration:underline;">In any case, you need to make sure your users won’t be frustrated by implementing the following points:</span>_

* Adding disclaimers when we can’t display the Green-Score
    * **<span style="text-decoration:underline;">Add a message if we have a category but no Green-Score</span>**
        * _if “en:categories-completed” _in states_tags_ **<span style="text-decoration:underline;">AND</span>** ecoscore_grade=Null_
            * We could not compute an Green-Score for this product. It might be that the category is not specific enough or that we don't have supporting data for this category. If you believe this is an error, you can email [contact@example.com](mailto:contact@example.com)
            * You can get states with [https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade,states_tags ](https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade,states_tags)
    * **<span style="text-decoration:underline;">Help the user add the category if it is missing</span>**
        * You can use our Robotoff API to get your users to validate a prediction
            * [Robotoff Questions](https://docs.google.com/document/d/1IoDy0toQrrqtWHvDYp2rEVw84Yq1J0x2pt-0RGTm7h0/edit)
* Adding disclaimers when the Green-Score is computed with a data gap + Asking the users to photograph and/or complete missing information
    * **<span style="text-decoration:underline;">Add a message if no labels are available</span>**
        * if "en:labels-to-be-completed" in states_tags
            * `"The Green-Score takes into account environmental labels. Please take them into photo or edit the product so that they can be taken into account"`
        * Asking your users for a photo should be enough
        * You can otherwise add toggles for Explicit labels (please add a photo of them to avoid mistakes)
        * You can get states with [https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade,states_tags ](https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade,states_tags)
    * **<span style="text-decoration:underline;">Add a message if no origins are available</span>**
        * if "en:origins-to-be-completed" in states_tags
            * `"The Green-Score takes into account the origins of the ingredients. Please take them into a photo (ingredient list and/or any geographic claim or edit the product so that they can be taken into account. If it is not clear, you can contact the food producer."`
            * You can get states with [https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade,states_tags ](https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade,states_tags)
    * **<span style="text-decoration:underline;">Add a message if recycling information is missing</span>**
        * if "en:packaging-photo-to-be-selected" in states_tags
            * [Add a button to take a picture of the recycling instructions · Issue #3531 · openfoodfacts/openfoodfacts-androidapp](https://github.com/openfoodfacts/openfoodfacts-androidapp/issues/3531) 
        * if "en:packaging-to-be-completed" in states_tags
            * you can get your users to type it, take a photo, or have a combinatory picker with packaging type, packaging material, packaging recyclability
            * The field to input raw recycling instructions eg: “Plastic bottle to recycle, Plastic cap to recycle” is “packaging_text_en” (change the language code accordingly)
            * It will get automatically parsed and get used to compute the Green-Score
        * You can get states with [https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade,ecoscore_alpha,states_tags](https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade,ecoscore_alpha,states_tags) 
    * **<span style="text-decoration:underline;">Sharing some of your code</span>**
        * You are very welcome to implement data contribution in one of our SDKs. The more apps let their user add photos and data, the more Green-Scores we get.


### Adding value by explaining

* Product Attributes
* You can implement the product attributes API that displays additional information with a minimum of coding
    * Full API documentation: [https://wiki.openfoodfacts.org/Product_Attributes](https://wiki.openfoodfacts.org/Product_Attributes)
    * Visual mockups: [https://github.com/openfoodfacts/openfoodfacts-androidapp/issues/3501](https://github.com/openfoodfacts/openfoodfacts-androidapp/issues/3501) 
    * A Flutter implementation is available, and you are very welcome to contribute implementation in one of our existing SDKs (or create your own)
* Explanation of Green-Score computations
    * [https://world-fr.openfoodfacts.org/api/v0/product/0634065322366.json?fields=environment_infocard,ecoscore_grade](https://world-fr.openfoodfacts.org/api/v0/product/0634065322366.json?fields=environment_infocard,ecoscore_grade) 
    * HTML explanation. You can get the localized version by changing world-fr into world-de
    * The HTML explanation is already available in the openfoodfacts-dart package

### Additional ways to get ready

* Onboarding producers you know
* You can ask any producer you know to get in touch with us at [producers@openfoodfacts.org](mailto:producers@openfoodfacts.org) so that their products are Green-Score ready in terms of data (we have easy ways to import their data using the Producer Platform: [https://world.pro.openfoodfacts.org/](https://world.pro.openfoodfacts.org/) )
