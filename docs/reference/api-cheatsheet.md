# Open Food Facts API - CheatSheet

This reference cheatsheet gives you a quick reminder to send requests to the OFF API.

If you are new to API usage you might look at the [tutorial](../tutorials/using-the-OFF-API-tutorial.md).
Also, refer to the [API reference documentation](../reference/api.md) for complete information.

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
