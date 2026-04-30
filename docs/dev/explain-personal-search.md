# Explain personal search

Personal search is a feature to let users
rank and score products according to their preferences.

It can be applied on the website and the mobile.

This is a very distinctive feature of Open Food Facts
and close to our goal of enabling personalized usage of the data.

Bear in mind that user preferences for food is sensitive information that must not be exposed.

## Preferences

Setting preferences happens client-side and is stored in browser or app local storage.

The user can enter, for different attributes,
how important each is according to their preferences.

Attributes are grouped into sections (called groups).

The attributes are accessible using `/api/v1/attribute_groups_<language_code>[^attributes_code]`,
eg `https://world.openfoodfacts.org/api/v1/attribute_groups_en`.

A panel is displayed in the web page using javascript to let users set their preferences[^prefsjs].

[^prefsjs]: see product-preferences.js


## Scoring

### Computing product match for each attribute

On a product, for each attribute, we compute a match score for each requirement.

This matching could depend on the country and maybe other data,
for example for environmental impact.

Each attribute has a specific algorithm for computing the match score.

The Attributes.pm module contains functions to compute those attributes.
It is exposed in the API in the `attribute_groups` properties
(not returned by default, you have to explicitly ask for it).

See also: https://wiki.openfoodfacts.org/Product_Attributes

### Computing product match according to user preferences

We first compute a numerical score as follow:

* all "not important" attributes according to user preferences are ignored
* for each remaining attributes:
  * we take the weight based upon users preferences (2 for mandatory and very important, 1 for important)
  * we take the "match" score of the product for this attribute
* the score is the weighed average of individual attribute scores; it is between 0 and 100 (as match)
* we also keep track of weights of unknown attributes vs weights of all attributes

The final match status is computed as follow:
* very_good_match	score >= 75
* good_match		score >= 50
* poor_match		score < 50
* unknown_match		at least one mandatory attribute is unknown, or unknown attributes weigh more than 50% of the total weight
* may_not_match		at least one mandatory attribute score is `<=` 50 (e.g. may contain traces of an allergen)
* does_not_match	at least one mandatory attribute score is `<=` 10 (e.g. contains an allergen, is not vegan)

For the web, this is implemented in `product-search.js`, in function `match_product_to_preferences`

Note: Currently, preferences_factors are hardcoded in `product-search.js`,
  while we have a preference api /api/v2/preferences which should be used
  but does not seem up to date.
  See issue [#10406](https://github.com/openfoodfacts/openfoodfacts-server/issues/10406)

When personal search is activated,
the match status is displayed on product pages, and on search for each item.

## Ranking

On the website main search page, users can sort products of the current page
according to their preferences. This is done in javascript.

In the mobile app, this is possible on lists.

The comparison is not based upon match status, but upon computed score,
with an extra malus for does_not_match.

We guarantee this order:
1. very_good_match
2. good_match
3. poor_match
4. does_not_match

But unknown_match and may_not_match may be in-between those values.

[^rank_products]: See `product-search.js` function `rank_products`
