# Tutorial on using the Open Food Facts API

Welcome to this tutorial on basic usage of Open Food Facts API.

First, be sure to see our [Introduction to the API](./index.md).

## Scan A Product To Get Nutri-score

This basic tutorial shows you can get the Nutri-score of a product, for instance, to display it in a mobile app after scanning the product barcode. Let's use [Nutella Ferrero](https://world.openfoodfacts.net/product/3017624010701/nutella-nutella-ferrero) as the product example for this tutorial.

To get a product nutriscore, send a request to the [Get A Product By Barcode](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#get-/api/v2/product/-barcode-) endpoint.

### Authentication

Usually, no authentication is required to query Get A Product Nutri-score. However, there is a basic auth to avoid content indexation in the staging environment(which is used throughout this tutorial). For more details, visit the [Open Food Facts API Environment](index.md#api-deployments).

### Describing the Get Request

Make a `GET` request to the `Get A Product By Barcode` endpoint.

```text
https://world.openfoodfacts.net/api/v2/product/{barcode}
```

The `{barcode}` is the barcode number of the product you are trying to get. The barcode for **Nutella Ferrero** is **3017624010701**. Then the request path to get product data for **Nutella Ferrero** will look like this:

```text
https://world.openfoodfacts.net/api/v2/product/3017624010701
```

The response returns every data about Nutella Ferrero on the database. To get the nutriscore, we need to limit the response by specifying the nutriscore field, which is the `nutrition_grades` and `product_name`.
<!--Is it only nutriscore_data -->

### Query Parameters

To limit the response of the Get A Product By Barcode response, use query parameters to specify the product fields to be returned. In this example, you need one query parameter called `field` with the value `product_name,nutrition_grades`.

The request path will now look like this:

```text
https://world.openfoodfacts.net/api/v2/product/3017624010701?fields=product_name,nutriscore_data
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

```text
https://world.openfoodfacts.net/api/v2/product/3017624010701?fields=product_name,nutriscore_data,nutriments,nutrition_grades
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

For more details, see the reference documentation for [Get A Product By Barcode](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#get-/api/v2/product/-barcode-).

<!-- Probably have a conclusion that links to the next possible topic eg filter countries using lc and cc-->

## Completing products to get the Nutri-Score

### Products without a Nutri-Score

When these fields are missing in a nutriscore computation response, it signifies that the product does not have a Nutri-Score computation due to some missing nutrition data.
Let's look at the [100% Real Orange Juice](https://world.openfoodfacts.net/api/v2/product/0180411000803/100-real-orange-juice?product_name,nutriscore_data,nutriments,nutrition_grades). If the product nutrition data is missing some fields, you can volunteer and contribute to it by getting the missing tags and writing to the OFF API to add them.

<!-- I dont know if using 100% Real Orange Juice is a good approach for now , should we state that it was not computed at the time of writing this article just incase it gets computed in future or there is a product we can use to test this that wont change in future ? -->

To know the missing tags, check the `misc-tags` field from the product response.

`https://world.openfoodfacts.net/api/v2/product/0180411000803/100-real-orange-juice?fields=misc_tags`

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

The WRITE operations in the OFF API require  authentication. Therefore you need a valid `user_id` and `password` to write the missing nutriment data to 100% Real Orange Juice.

> Sign up on the [Open Food Facts App](https://world.openfoodfacts.net/) to get your`user_id` and `password` if you don't have one.

To write data to a product, make a `POST` request to the [`Add or Edit A Product`](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#post-/cgi/product_jqm2.pl) endpoint.

```text
https://world.openfoodfacts.net/cgi/product_jqm2.pl
```

Add your valid `user_id` and `password` as body parameters to your request for authentication. The `code` (barcode of the product to be added/edited), `user_id`, and `password` are required when adding or editing a product. Then, include other product data to be added in the request body.

To write `sodium` and `category` to 100% Real Orange Juice so that the Nutri-Score can be computed, the request body should contain these fields :

| Key        | Value           | Description  |
| ------------- |:-------------:| -----:|
| user_id     | *** | A valid user_id |
| password      | ***     |   A valid password |
| code | 0180411000803      |    The barcode of the product to be added/edited |
| nutriment_sodium | 0.015      |    Amount of sodium |
| nutriment_sodium_unit | g      |   Unit of sodium relative to the amount |
| categories | Orange Juice     |   Category of the Product |

Using curl:

```bash
curl -XPOST -x POST https://world.openfoodfacts.net/cgi/product_jqm2.pl \
  -F user_id=your_user_id -F password=your_password \
  -F code=0180411000803 -F nutriment_sodium=0.015 -F nutriment_sodium_unit=g -F categories="Orange Juice"
```

If the request is successful, it returns a response that indicates that the fields have been saved.

```json
{
    "status_verbose": "fields saved",
    "status": 1
}
```

### Read newly computed Nutri-Score

Now, let's check if the Nutri-Score for 100% Real Orange Juice has been computed now that we have provided the missing data. Make a GET request to `https://world.openfoodfacts.net/api/v2/product/0180411000803?fields=product_name,nutriscore_data,nutriments,nutrition_grades` for Nutri-Score of 100% Real Orange Juice. The response now contains the Nutri-Score computation:

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

For more details, see the reference documentation for [Add or Edit A Product](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#post-/cgi/product_jqm2.pl)

You can also check the reference cheatsheet to know how to add/edit other types of product data.

<!-- Include the link of the cheatsheet once it is published. -->

## Search for a Product by Nutri-score

Using the Open Food Facts API, you can filter products based on different criteria.  To search for products in the Orange Juice category with a nutrition_grade of `c`, query the [Search for Products endpoint](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#get-/api/v2/search).

### Describing the Search Request

Make a `GET` request to the `Search for Products` endpoint.

```text
https://world.openfoodfacts.org/api/v2/search
```

Add the search criteria used to filter the products as query parameters.  For Orange Juice with a nutrition_grade of `c`, add query parameters `categories_tags_en` to filter `Orange Juice` while `nutrition_grades_tags` to filter `c`.  The response will return all the products in the database with the category `Orange Juice` and nutrition_grade `c`.

```text
https://world.openfoodfacts.net/api/v2/search?categories_tags_en=Orange Juice&nutrition_grades_tags=c
```

To limit the response, add `fields` to the query parameters to specify the fields to be returned in each product object response.  For this tutorial, limit the response to `code`, `product_name`, `nutrition_grades`, and `categories_tags_en`.

```text
https://world.openfoodfacts.net/api/v2/search?categories_tags_en=Orange Juice&nutrition_grades_tags=c&fields=code,nutrition_grades,categories_tags_en
```

The response returns all products that belong to the Orange Juice category, with the nutrition_grade "c" and limits each product object response to only the specified fields.  It also returns the count(total number) of products that match the search criteria.

```json
{
    "count": 1629,
    "page": 1,
    "page_count": 24,
    "page_size": 24,
    "products": [
        {
            "categories_tags_en": [
                "Plant-based foods and beverages",
                "Beverages",
                "Plant-based beverages",
                "Fruit-based beverages",
                "Juices and nectars",
                "Fruit juices",
                "Concentrated fruit juices",
                "Orange juices",
                "Concentrated orange juices"
            ],
            "code": "3123340008288",
            "nutrition_grades": "c"
        },
        .
        .
        .
        {
            "categories_tags_en": [
                "Plant-based foods and beverages",
                "Beverages",
                "Plant-based beverages",
                "Fruit-based beverages",
                "Juices and nectars",
                "Fruit juices",
                "Non-Alcoholic beverages",
                "Orange juices",
                "Squeezed juices",
                "Squeezed orange juices"
            ],
            "code": "3608580844136",
            "nutrition_grades": "c"
        }
    ],
    "skip": 0
}
```

### Sorting Search Response

You can proceed to also sort the search response by different fields, for example, sort by the product that was modified last or even by the product_name. Now, let's sort the products with Orange Juice and a nutrition_grade of "c" by when they were last modified. To sort the search response, add the `sort_by` with value `last_modified_t` as a query parameter to the request.

```text
https://world.openfoodfacts.net/api/v2/search?nutrition_grades_tags=c&fields=code,nutrition_grades,categories_tags_en&categories_tags_en=Orange Juice&sort_by=last_modified_t
```

The date that each product was last modified is now used to order the product response.

```json
{
    "count": 1629,
    "page": 1,
    "page_count": 24,
    "page_size": 24,
    "products": [
        {
            "categories_tags_en": [
                "Plant-based foods and beverages",
                "Beverages",
                "Plant-based beverages",
                "Fruit-based beverages",
                "Juices and nectars",
                "Fruit juices",
                "Orange juices"
            ],
            "code": "3800014268048",
            "nutrition_grades": "c"
        },
        '
        '
        '
        {
            "categories_tags_en": [
                "Plant-based foods and beverages",
                "Beverages",
                "Plant-based beverages",
                "Fruit-based beverages",
                "Juices and nectars",
                "Fruit juices",
                "Orange juices",
                "Squeezed juices",
                "Squeezed orange juices"
            ],
            "code": "4056489641018",
            "nutrition_grades": "c"
        }
    ],
    "skip": 0
}
```

To see other examples of sorting a search response, see the reference documentation for [Search for Products](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#get-/api/v2/search).
