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

### Adding nutrition facts for the prepared product
You can send prepared nutritional values
* nutriment_energy-kj (regular)
* nutriment_energy-kj_prepared (prepared)

## Search for Products

**Important:** full text search currently works only for v1 API (or search-a-licious, which is in beta)

* [Documentation for v1 Search API](https://wiki.openfoodfacts.org/API/Read/Search)

* [Reference documentation for v2 search API](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#get-/api/v2/search)

* The future of search in Open Food Facts is the [search-a-licious project](https://github.com/openfoodfacts/search-a-licious), deployed, in beta, at [search.openfoodfacts.org](https://search.openfoodfacts.org/). It has an API: [Search-a-licious API](https://search.openfoodfacts.org/docs)

## Get suggestions for fields
### New solution: Search-a-licious (has all actually used values)
Get brands, categories, labels… suggestions using the [Search-a-licious API](https://search.openfoodfacts.org/docs). 
You can also use the classic suggest.pl route

### Legacy solution: suggest.pl (has all taxonomized values, and only taxonomized values)
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=emb_codes&term=FR
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=categories&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=labels&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=ingredients&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=packaging_shapes&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=packaging_materials&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=packaging_shapes&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=languages&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=stores&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=brands&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=countries&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=traces&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=origins&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=states&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=nutrients&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=additives&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=allergens&term=f
* https://world.openfoodfacts.org/cgi/suggest.pl?tagtype=minerals&term=f

### Get data for a list of products

You can use comma to separate multiple values of a query parameter. This allows you to make bulk requests. The product result can also be limited to specified data using `fields`.

```text
https://world.openfoodfacts.org/api/v2/search?code=3263859883713,8437011606013,6111069000451&fields=code,product_name
```

### Get taxonomy-based suggestions (v3 API)

The v3 API provides suggestions based on taxonomy fields such as synonyms, categories, and packaging shapes.

# Reference documentation:
https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v3/#get-/api/v3/taxonomy_suggestions

# Example requests:
Get suggestions from synonyms
```text
https://world.openfoodfacts.org/api/v3/taxonomy_suggestions?tagtype=labels&lc=fr&string=f&get_synonyms=1
```
Get suggestions for a specific category
```text
https://world.openfoodfacts.org/api/v3/taxonomy_suggestions?tagtype=categories&string=organic
```
Get suggestions based on packaging shape
```text
https://world.openfoodfacts.org/api/v3/taxonomy_suggestions?tagtype=packaging_materials&shape=box
```
