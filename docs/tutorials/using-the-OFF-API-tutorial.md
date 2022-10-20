# Using the Open Food Facts API
<!--Add a brief introduction of what the tutorial does -->
## Scan A Product To Get Nutri-score

This basic tutorial shows you can get the Nutri-score of a product, for instance, to display it in a mobile app after scanning the product barcode. Let's use [Nutella Ferrero](https://world.openfoodfacts.org/product/3017624010701/nutella-nutella-ferrero) as the product example for this tutorial.

<!-- Meet Dave. Dave is an active Open Food Facts contributor and a developer who wants to build HealthyFoodChoices, an Android app aimed at conscious consumers that buy healthy products. He has a consumer called Anna. Anna wants to know more on the nutritional facts of Nutella - Ferrero from the HealthyFoodChoices app. Dave needs his app to make an API call to provide her with this information. -->

To get a product nutriscore, you need to make a call to the [Get A Product By Barcode](https://openfoodfacts.github.io/openfoodfacts-server/reference/api.html#tag/Read-Requests/operation/get-product-by-barcode) Endpoint.

### Authentication

No Authentication is required to make a query to Get A Product Nutri-score.

### Describing the Request

Make a `GET` request to the `Get A Product By Barcode` endpoint.

```bash
https://world.openfoodfacts.org/api/v2/product/{barcode}
```

The `{barcode}` is the barcode number of the product you are trying to get. The barcode for **Nutella Ferrero** is **3017624010701**. Then the request path to get product data for **Nutella Ferrero** will look like this:

```bash
https://world.openfoodfacts.org/api/v2/product/3017624010701
```

The response returns every data about Nutella Ferrero on the database. To get the nutriscore, we need to limit the response by specifying the nutriscore field, which is the `nutrition_grades` and `product_name`.
<!--Is it only nutriscore_data -->

### Query Parameters

To limit the response of the Get A Product By Barcode response, use query parameters to specify the product fields to be returned. In this example, you need one query parameter called `field` with the value `product_name,nutrition_grades`.

The request path will now look like this:

```bash
https://world.openfoodfacts.org/api/v2/product/3017624010701?fields=product_name,nutriscore_data
```

### Nutri-score Response

The response returned contains an object of the `code`, `product`, `status_verbose`, and `status`. The `product` object contains the fields specified in the query: the `product_name` and the `nutrition_grades`. The status also states if the product was found or not.

```json
{
    "code": "3017624010701",
    "product": {
        "nutrition_grades": "e",
        "product_name": "Nutella"
    },
    "status": 1,
    "status_verbose": "product found"
}
```

### Nutri-score Computation

If you would like to be able to show how the score is computed, add some extra fields like `nutriscore_data` and `nutriments`.

The request path to get the nutriscore computation for Nutella-Ferroro will be :

```bash
https://world.openfoodfacts.org/api/v2/product/3017624010701?fields=product_name,nutriscore_data,nutriments,nutrition_grades
```

The `product` object in the response now contains the extra fields to show how the nutriscore was computed.

```json
{
    "code": "3017624010701",
    "product": {
        "nutriments": {
            "carbohydrates": 57.5,
            "carbohydrates_100g": 57.5,
            "carbohydrates_unit": "g",
            "carbohydrates_value": 57.5,
            "energy": 2255,
            "energy-kcal": 539,
            "energy-kcal_100g": 539,
            "energy-kcal_unit": "kcal",
            ...,
            ...,
            "sugars": 56.3,
            "sugars_100g": 56.3,
            "sugars_unit": "g",
            "sugars_value": 56.3
        },
        "nutriscore_data": {
            "energy": 2255,
            "energy_points": 6,
            "energy_value": 2255,
            ...,
            ...,
            "sugars_points": 10,
            "sugars_value": 56.3
        },
        "nutrition_grades": "e",
        "product_name": "Nutella"
    },
    "status": 1,
    "status_verbose": "product found"
}
```
<!-- Probably have a conclusion that links to the next possible topic eg filter countries using lc and cc-->