**Dave** wants his app to make an API call to provide Stefano healthy plant-based breakfast cereals.
--- 
- **This is a search usecase.** Please note that search is not a good way to extract info from the database, and anyone trying to do that will be rate-limited and banned. Please use the https://world.openfoodfacts.org/data](https://world.openfoodfacts.org/data) for super convenient data export of the whole database and images that you can slice and dice easily.
- Also note that we have an elastic-based revamp of the Search API upcoming, called search-a-licious, and we need some more developper help to make it broadly available. You can join the effort at https://github.com/openfoodfacts/search-a-licious](https://github.com/openfoodfacts/search-a-licious) and on the Slack (https://slack.openfoodfacts.org](https://slack.openfoodfacts.org), #search channel)


---

## Authentication and Header

To make the API query that returns the products that might be interesting for Anna, Dave doesn't need to authenticate. However, he has to add a User-Agent HTTP Header with the name of his app, the version, system and a url (if any), not to be blocked by mistake.

In this case, that would be: `User-Agent: HealthyFoodChoices - Android - Version 1.0`

---

## Subdomain

Since Stefano lives in Italy, Dave wants to define the subdomain for the query as us. The subdomain automatically defines the country code (`cc`) and language of the interface (`lc`).

The country code determines that only the products sold in the Italy are displayed. The language of the interface for the country code `it` is Italian.

In this case:

[https://it.openfoodfacts.org](https://it.openfoodfacts.org)

---

## Query Parameters

Dave wants to fine-tune the query to provide Anna with the products that match her buying preferences. To do so, he wants to drill down the results to display only breakfast cereals.

First, he adds the following sequence after the https call: `/cgi/search.pl?` (all search queries need to include this)

Then, he defines some tags and the appropriate values: `action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals`

where:

- `action` introduces the action to be performed (process)
- `tagtype_0` adds the first search criterion (categories)
- `tag_contains_0=contains` determines that the results should be included (note that you can exclude products from the search)
- `tag_0` defines the category to be filtered by (breakfast_cereals)
    

**Note:** The parameters are concatenated with `&`.

To retrieve breakfast cereals sold in the US, Dave makes the following: [https://us.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals](https://us.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals)

With this query, the nutrition facts of more than 200 products are displayed.

Then, Dave wants to exclude the products that contain ingredients from palm oil. He adds a new parameter to the query:

- `ingredients_from_palm_oil=without`
    

This parameter excludes the products that might contain palm oil ingredients from the search.

[https://us.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals&ingredients_from_palm_oil=without](https://us.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals&ingredients_from_palm_oil=without)

Next, Dave adds another parameter to exclude the products that contain additives:

- `additives=without`
    

The query is as follows:

[https://us.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals&ingredients_from_palm_oil=without&additives=without](https://us.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals&ingredients_from_palm_oil=without&additives=without)

Finally, Dave adds another parameter to include only products with a nutriscore A. The nutriscore is a nutrition grade determined by the amount of healthy and unhealthy nutrients.

- `tagtype_1=nutrition_grade`
- `tag_contains_1=contains`
- `tag_1=A`
    

The complete query looks like this:

[https://us.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals&tagtype_1=nutrition_grades&tag_contains_1=contains&tag_1=A&additives=without&ingredients_from_palm_oil=without](https://us.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals&tagtype_1=nutrition_grades&tag_contains_1=contains&tag_1=A&additives=without&ingredients_from_palm_oil=without)

Add the json=true parameter to avoid scraping.

[https://us.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals&tagtype_1=nutrition_grades&tag_contains_1=contains&tag_1=A&additives=without&ingredients_from_palm_oil=without&json=true](https://us.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals&tagtype_1=nutrition_grades&tag_contains_1=contains&tag_1=A&additives=without&ingredients_from_palm_oil=without&json=true)

Anna can see now at a glance which products match her search criteria. In this case, around 20 brands of breakfast cereals.
