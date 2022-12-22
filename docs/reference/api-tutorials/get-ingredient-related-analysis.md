Dev Journey 6: Get ingredient related analysis on new or existing products (Nova, allergens, additives…)

- If you can't get the information on a specific product, you can get your user to send photos and data.
- That will then be processed by Open Food Facts to get the computed result you want to show them.
- You can implement the complete flow so that they get immediately the result with some effort on their side.
- That will ensure user satisfaction
    

[https://docs.google.com/document/d/1avnxJr8_m6OjRBt0vgwBzlzaZB7Q6z14t0taMKIrkp0/edit](https://docs.google.com/document/d/1avnxJr8_m6OjRBt0vgwBzlzaZB7Q6z14t0taMKIrkp0/edit)

You can get information about absence or unawareness of the presence of:

- **palm oil**: `palm-oil-free`, `palm-oil`, `palm-oil-content-unknown`, `may-contain-palm-oil`
- **vegetarian ingredients**: `vegetarian`, `non-vegetarian`, `vegetarian-status-unknown`, `maybe-vegetarian`.
- **vegan ingredients**: `vegan`, `non-vegan`, `vegan-status-unknown`, `maybe-vegan`.
    
**Important!** Parsing might not be perfect and the ingredient detection might have issues in some languages. For more information on how you can help improve it, see: [https://github.com/openfoodfacts/openfoodfacts-server/blob/master/taxonomies/ingredients.txt](https://github.com/openfoodfacts/openfoodfacts-server/blob/master/taxonomies/ingredients.txt)
