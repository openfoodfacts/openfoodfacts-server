# Explain personal search

Personal search is a feature to enable users
to rank and score products according to their preferences.

It can be applied on the website and the mobile.

This is a very distinctive feature of Open Food Facts
and close to our value to enable personalized usage of the data.

Bear in mind that user preferences for food is a sensitive information that must not be exposed.

## Preferences

The configuration of preferences happens client side and is stored in browser or app local storage.

The user can tell for different attributes
what is the importance of each according to his preferences.

Attributes are grouped by sections (called groups).

The attributes are accessible in at `/api/v1/attribute_groups_<language_code>[^attributes_code]`,
eg https://world.openfoodfacts.org/api/v1/attribute_groups_en

A panel is generated in the web page using javascript to enable users to set their preferences[^prefsjs]

[^prefsjs]: see product-preferences.js


## Scoring

### Computing product match for each attribute

On a product, for each attribute, we compute a match score for each product.

This matching might take into account the country and, maybe, some other data,
for example for environmental impact.

Each attribute as a specific computation and specific way to compute the matching score.

The Attributes.pm module contains functions to compute those attributes.
It is exposed in the API in the `attribute_groups` properties
(not returned by default, you have to explicitly ask for it).

See also: https://wiki.openfoodfacts.org/Product_Attributes

### Computing product match according to user preferences

We first compute a numerical score as follow:

* all "not important" attributes according to user preferences, are dismissed
* for each attributes:
  * else we take the weight based upon users preferences (2 for mandatory and very important, 1 for important)
  * we take the "match" score of the product for this attributes
* the score is the ponderated mean of attributes, it is between 0 and 100 (as match)
* we also keep track of weights of unknown attributes vs weights of all attributes

The final match status is computed as follow:
* very_good_match	score >= 75
* good_match		score >= 50
* poor_match		score < 50
* unknown_match		at least one mandatory attribute is unknown, or unknown attributes weights more than 50% of the total weights
* may_not_match		at least one mandatory attribute score is <= 50 (e.g. may contain traces of an allergen)
* does_not_match	at least one mandatory attribute score is <= 10 (e.g. contains an allergen, is not vegan)

For the web, this is implemented in `product-search.js`, in function `match_product_to_preferences`

Note: Currently, preferences_factors are hardcoded in `product-search.js`,
  while we have a preference api /api/v2/preferences which should be used
  but does not seem up to date.
  See issue [#10406](https://github.com/openfoodfacts/openfoodfacts-server/issues/10406)

When personal search is activated,
the match status is displayed on products pages, and on search, for each item.

## Ranking

On the website main search page, in the website users can sort products of the current page
according to their preferences. This is done by javascript.

In the mobile, this is possible on lists.

The comparison is not based upon match status, but upon computed score,
with an extra malus for does_not_match.

We have the guarantee to have this order:
1. very_good_match
2. good_match
3. poor_match
4. does_not_match

But unknown_match and may_not_match may be in-between those values.

[^rank_products]: See `product-search.js` function `rank_products`
