# Scan A Product To Get Nutriscore

This is a basic tutorial that shows you how to scan a product to get the nutriscore field. 

Meet Dave. Dave is an active Open Food Facts contributor and a developer who wants to build HealthyFoodChoices, an Android app aimed at conscious consumers that buy healthy products. He has a consumer called Anna. Anna wants to know more on the nutritional facts of Nutella - Ferrero from the HealthyFoodChoices app. Dave needs his app to make an API call to provide her with this information.

<!-- I am not sure If I should retain this scenario of Dave and Anna, Pierre suggested it -->

## Structure of the Call

To get a products nutriscore, you need to make a call to the Get A Product By Barcode Endpoint.

**Authentication**
No Authentication is required to make a query to Get A Product Nutriscore.

**Describing the Request**
Make a request to this Get A Product By Barcode endpoint.

```https://world.openfoodfacts.org/api/v2/product/{barcode}
```

The {barcode} is the barcode number of the product you are trying to get. The barcode for Nutella Ferrero is 3017624010701. Then the request will be :

```https://world.openfoodfacts.org/api/v2/product/3017624010701
```

This request will returning every information about Nutella Ferrero on the database. In order to get the nutri-score, we need to limit the response by specify the nutriscore field which is the `nutriscore_data`.
<!--Is it only nutriscore_data -->

**Query Parameters**
To limit the response of Get A Product By Barcode response , use query parameters to specify the fields of the product to be returned. In this example you need one query parameter called field with the value product_name,nutriscore_data . The key of the parameter is fields and the value

**Nutriscore Response**
The response returns an object with the code, product object and status. The product object contains the fields specified in the query which is the product_name and the nutriscore_data. The status also states if the product was found or not.

```{
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
            "product_name": "Nutella"
        },
        "status": 1,
        "status_verbose": "product found"
    }
```
<!-- Probably have a conclusion that links to the next possible topic eg filter countries using lc and cc-->