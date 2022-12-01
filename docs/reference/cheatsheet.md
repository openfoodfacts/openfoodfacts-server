# Open Food Facts Reference CheatSheet

This reference cheatsheet shows you quick tips to remember when using the Open Food Facts API. It is more useful to those who are familiar with the [reference documentation](https://openfoodfacts.github.io/openfoodfacts-server/reference/api/).

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
