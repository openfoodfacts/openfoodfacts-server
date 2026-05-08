# Open Beauty Facts, Open Pet Food Facts, Open Products Facts experimental and specific APIs

- Open Beauty Facts, Open Pet Food Facts, Open Products Facts behave mostly like Open Food Facts. Behaviours may change over time, as we tweak it.

#### Specific base URLs

- Cosmetics: The base URL is openbeautyfacts.org instead of openfoodfacts.org
- Pet Food: The base URL is openpetfoodfacts.org instead of openfoodfacts.org
- Other type of products: The base URL is openproductsfacts.org instead of openfoodfacts.org

#### Different behaviours common to Open Beauty Facts, Open Pet Food Facts, Open Products Facts

- The same codebase: Knowledge panels are supported, the new packaging API is supported
- Search-a-licious, Open Prices, Folksonomy Engine, Nutri-Patrol not supported yet
- No Robotoff questions yet

#### Specificities of Open Beauty Facts

- No nutrition table
- No Green-Score, Nutri-Score or NOVA groups for ultra-processing

#### Specificities of Open Pet Food Facts

- No Green-Score, Nutri-Score or NOVA groups for ultra-processing

#### Specificities of Open Products Facts

- No nutrition table
- No Green-Score, Nutri-Score or NOVA groups for ultra-processing
- Most data will be modelled using the [Folksonomy Engine](docs/api/tutorials/folksonomy-engine.md)

### Important APIs if you want to scan any kind of product (or help your users avoid adding cosmetics by mistake in Open Food Facts)

- We have a universal barcode scanning API, where you scan a barcode, and you get a result from either Open Food Facts, Open Pet Food Facts, Open Beauty Facts or Open Products Facts with a `product_type` (beauty ┃ food ┃ petfood ┃ product), you can use the `product_type=all` parameter. Asked on any instance, it will redirect you to the right instance if a product exists and is on another instance (eg: asking for a beauty barcode on food instance). See [reference documentation](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/#get-/api/v2/product/-barcode-).
- https://world.openfoodfacts.org/api/v2/product/3760044183738?product_type=all (will redirect you to the proper payload on Open Products Facts)
- If no result is found in any of the 4 databases, you will have to ask the type of product to your users, and use the classic product addition API on the right project.
- If (it can happen) the product appears on the wrong project, we suggest you use the NutriPatrol API to let your users report it to the moderators, and the proceed to a product addition on the right project. The moderators will then move the existing data to the right project. Eventually, project categorization errors should be infinitesimal.

### API Roadmap and multi-project behaviour

- We plan to bring the APIs mentionned above to Open Beauty Facts (Search-a-licious, Knowledge Panels, Open Prices, Robotoff, Folksonomy Engine)

### Sample outputs

- Please use the Open Food Facts API reference for most operations (data and photo addition, ingredient lists, categories, labels…)

### WRITE Operations

- You can do WRITE operations on the right server, but normally all servers should forward operations automatically based on the `product_type`
- For cosmetic, the crucial thing we need is an ingredient photo
- For pet food, the crucial thing we need is an ingredient photo and a nutrition photo
- For other products, you should encourage the users to take photos of all angles of the packaging of the product, since variability is high across categories and there's a lot of information.

#### Product in Open Beauty Facts

- https://world.openbeautyfacts.org/api/v2/product/3560070791460.json

#### Warning on specific ingredients

- Note: we'll soon have an elegant way to let your users block ingredients using product attributes.

#### Ingredients on Open Beauty Facts

##### List of ingredients on Open Beauty Facts

- https://world.openbeautyfacts.org/ingredients.json

##### Products where we could not detect aluminium salts

- https://world.openbeautyfacts.org/ingredient/-aluminum-salts.json

##### Products where we could detect aluminium salts

- https://world.openbeautyfacts.org/ingredient/aluminum-salts.json

#### Periods after Opening

[https://en.wiki.openbeautyfacts.org/Global_period_after_opening_taxonomy Periods after opening taxonomy]
