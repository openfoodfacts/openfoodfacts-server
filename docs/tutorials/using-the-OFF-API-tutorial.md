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

### Nutri-Score Response

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

### Nutri-Score Computation

If you would like to be able to show how the score is computed, add some extra fields like `nutriscore_data` and `nutriments`.

The request path to get the Nutri-Score computation for Nutella-Ferroro will be :

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

For more details, see the reference documentation for [Get A Product By Barcode](https://openfoodfacts.github.io/openfoodfacts-server/reference/api.html#tag/Read-Requests/operation/get-product-by-barcode)

<!-- Probably have a conclusion that links to the next possible topic eg filter countries using lc and cc-->

## Completing products to get the Nutri-Score

### Products without a Nutri-Score

When these fields are missing in a nutriscore computation response, it means that the product does not have a Nutri-Score computation due to some missing nutrition data.

Lets look at the [100% Real Orange Juice](https://world.openfoodfacts.org/api/v2/product/0180411000803/100-real-orange-juice?product_name,nutriscore_data,nutriments,nutrition_grades). If the product nutrition data is missing some fields, you can volunteer and contribute to it by getting the missing tags and writing to the OFF API to add them.

<!-- I dont know if using 100% Real Orange Juice is a good approach for now , should we state that it was not computed at the time of writing this article just incase it gets computed in future or there is a product we can use to test this that wont change in future ? -->

To know the missing tags, you need the `misc-tags` field from the response.

`https://world.openfoodfacts.org/api/v2/product/0180411000803/100-real-orange-juice?fields=misc_tags`

The response shows the missing fields and category needed to compute the Nutri-Score.

```json
{
    "code": "0180411000803",
    "product": {
        "misc_tags": [
            "en:nutriscore-not-computed",
            "en:nutriscore-missing-category",
            "en:nutrition-not-enough-data-to-compute-nutrition-score",
            "en:nutriscore-missing-nutrition-data",
            "en:nutriscore-missing-nutrition-data-sodium",
            "en:ecoscore-extended-data-not-computed",
            "en:ecoscore-not-computed",
            "en:main-countries-new-product"
        ]
    },
    "status": 1,
    "status_verbose": "product found"
}
```

The sample response above for 100% Real Orange Juice `misc_tags` shows that the Nutri-Score is missing category (`en:nutriscore-missing-category`) and sodium(salt) (`en:nutriscore-missing-nutrition-data-sodium`). Now you can write to the OFF API to provide these nutriment data (if you have them) so that the Nutri-Score can be computed.

### Write data to make Nutri-Score computation possible

The WRITE operations in the OFF API require authentication, therefore you need a valid `user_id` and `password`  to write the missing nutriment data to 100% Real Orange Juice. 

> Sign up on the [Open Food Facts App](https://world.openfoodfacts.org/), to get your `user_id` and `password` if you dont have.

To write data to a product, make a `POST` request to the [`Add or Edit A Product`](https://openfoodfacts.github.io/openfoodfacts-server/reference/api.html#tag/Write-Requests/operation/post-cgi-product_jqm2.pl) endpoint.

```text
https://world.openfoodfacts.org/cgi/product_jqm2.pl
```

For authentication, add your valid `user_id` and `password` as body parameters to your request. The `code` (barcode of the product to be added/edited), `user_id` and `password` are required fields when adding or editing a product. Then, include other product data to be added in the request body.

To write `sodium` and `category` to 100% Real Orange Juice so that the Nutri-Score can be computed, the request body should contain these fields :

| Key        | Value           | Description  |
| ------------- |:-------------:| -----:|
| user_id     | *** | A valid user_id |
| password      | ***     |   A valid password |
| code | 0180411000803      |    The barcode of the product to be added/edited |
| nutriment_sodium | 0.015      |    Amount of sodium |
| nutriment_sodium_unit | g      |   Unit of sodium relative to the amount |
| categories | Orange Juice     |   Category of the Product |

If the request is succesful, it returns a response that indicated that the fields have been saved.

```json
{
    "status_verbose": "fields saved",
    "status": 1
}
```

Now, let's check if the Nutri-Score for 100% Real Orange Juice has been computed now that we have provided the missing data. Make a GET request to `https://world.openfoodfacts.org/api/v2/product/0180411000803?fields=product_name,nutriscore_data,nutriments,nutrition_grades` for Nutri-Score of 100% Real Orange Juice. The response now contains the Nutri-Score computation:

```json
{
    "code": "0180411000803",
    "product": {
        "nutriments": {
            "carbohydrates": 11.864406779661,
            .
            .
            .
            "sugars_unit": "g",
            "sugars_value": 11.864406779661
        },
        "nutriscore_data": {
            "energy": 195,
            "energy_points": 7,
            "energy_value": 195,
            .
            .
            .
            "sugars_value": 11.86
        },
        "nutrition_grades": "c",
        "product_name": "100% Real Orange Juice"
    },
    "status": 1,
    "status_verbose": "product found"
}
```

Visit the [Wiki](https://wiki.openfoodfacts.org/API/Write#Editing_an_existing_product) to know how to add/edit other types of product data.

<!-- The wiki is a really good source of info that shows how to add different types of product data , however it has some outdated info so I am proposing to edit oit so this linking can be effective. -->