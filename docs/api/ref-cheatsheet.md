# Reference: API CheatSheet 

This reference cheatsheet gives you a quick reminder to send requests to the OFF API.

If you are new to API usage you might look at the [tutorial](tutorial-off-api.md).
Also, refer to the [API reference documentation](ref-v2.md) for complete information.

## Add/Edit an Existing Product

### Indicate the absence of nutrition facts

```text
no_nutrition_data=on (indicates if the nutrition facts are not indicated on the food label)
```

### Add nutrition facts values, units and base

```text
nutrition_data_per=100g

OR

nutrition_data_per=serving
serving_size=38g
```

```text
nutriment_energy=450
nutriment_energy_unit=kJ
```

### Adding values to a field that is already filled

> You just have to prefix `add_` before the name of the field

```text
add_categories
add_labels
add_brands
```

## Search for Products

[Reference documentation for search API](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#get-/api/v2/search)

### Get data for a list of products

You can use comma to separate multiple values of a query parameter. This allows you to make bulk requests. The product result can also be limited to specified data using `fields`.

```text
https://world.openfoodfacts.org/api/v2/search?code=3263859883713,8437011606013,6111069000451&fields=code,product_name
```
