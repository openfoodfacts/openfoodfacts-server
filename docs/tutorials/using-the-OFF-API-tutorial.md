# Using the Open Food Facts API

## Scan A Product To Get Nutriscore

This basic tutorial shows you can get the Nutriscore of a product, for instance, to display it in a mobile app after scanning the product barcode. Let's use [Nutella Ferrero](https://world.openfoodfacts.org/product/3017624010701/nutella-nutella-ferrero) as the product example for this tutorial.

<!-- Meet Dave. Dave is an active Open Food Facts contributor and a developer who wants to build HealthyFoodChoices, an Android app aimed at conscious consumers that buy healthy products. He has a consumer called Anna. Anna wants to know more on the nutritional facts of Nutella - Ferrero from the HealthyFoodChoices app. Dave needs his app to make an API call to provide her with this information. -->

### Structure of the Call

To get a product nutriscore, you need to make a call to the [Get A Product By Barcode](https://openfoodfacts.github.io/openfoodfacts-server/reference/api.html#tag/Read-Requests/operation/get-product-by-barcode) Endpoint.

### Authentication

No Authentication is required to make a query to Get A Product Nutriscore.

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

### Nutriscore Response

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

### Nutriscore Computation

If you would like to be able to show how the score is computed, add some extra fields like `nutriscore_data` and `nutrition_data`.

The request path to get the nutriscore computation for Nutella-Ferroro will be :

```bash
https://world.openfoodfacts.org/api/v2/product/3017624010701?fields=product_name,nutrition_grades,nutriscore_data,nutrition_data,
```

The `product` object in the response now contains the extra fields to show how the nutriscore was computed.

```json
{
    "code": "3017624010701",
    "product": {
        "nutriscore_data": {
            "energy": 2255,
            "energy_points": 6,
            "energy_value": 2255,
            "fiber": 0,
            "fiber_points": 0,
            "fiber_value": 0,
            "fruits_vegetables_nuts_colza_walnut_olive_oils": 0,
            "fruits_vegetables_nuts_colza_walnut_olive_oils_points": 0,
            "fruits_vegetables_nuts_colza_walnut_olive_oils_value": 0,
            "grade": "e",
            "is_beverage": 0,
            "is_cheese": 0,
            "is_fat": 0,
            "is_water": 0,
            "negative_points": 26,
            "positive_points": 0,
            "proteins": 6.3,
            "proteins_points": 3,
            "proteins_value": 6.3,
            "saturated_fat": 10.6,
            "saturated_fat_points": 10,
            "saturated_fat_ratio": 34.3042071197411,
            "saturated_fat_ratio_points": 5,
            "saturated_fat_ratio_value": 34.3,
            "saturated_fat_value": 10.6,
            "score": 26,
            "sodium": 43,
            "sodium_points": 0,
            "sodium_value": 43,
            "sugars": 56.3,
            "sugars_points": 10,
            "sugars_value": 56.3
        },
        "nutrition_data": "on",
        "nutrition_grades": "e",
        "product_name": "Nutella"
    },
    "status": 1,
    "status_verbose": "product found"
}
```

<!-- Probably have a conclusion that links to the next possible topic eg filter countries using lc and cc-->