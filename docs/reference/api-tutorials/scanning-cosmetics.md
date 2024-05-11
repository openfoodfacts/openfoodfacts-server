### Open Beauty Facts experimental and specific APIs

Open Beauty Facts behaves mostly like Open Food Facts. Behaviours may change over time, as we tweak it.

#### Specificities of Open Beauty Facts
* No nutrition table
* No Eco-Score, Nutri-Score or NOVA level for ultra-processing
* Old codebase, being upgraded very soon. Knowledge panels are not supported, the new packaging API is not supported
* Search-a-licious, Open Prices not supported yet
* No Robotoff questions yet

### API Roadmap
* We plan to have a universal barcode scanning API, where you scan a barcode, and you get a result from either Open Food Facts, Open Pet Food Facts, Open Beauty Facts or Open Products Facts
* If no result is found in any of the 4 databases, you will have to ask the type of product to your users, and use the classic product addition API on the right project.
* If (it can happen) the product appears on the wrong project, we suggest you use the NutriPatrol API to let your users report it to the moderators, and the proceed to a product addition on the right project. The moderators will then move the existing data to the right project. Eventually, project categorization errors should be infinitesimal.

#### Product in Open Beauty Facts
* https://world.openbeautyfacts.org/api/v2/product/3560070791460.json

#### Ingredients
*Very experimental. Do not rely on this for allergen or ingredient parsing yet.*
##### List of ingredients detected by the current experimental parser
* https://world.openbeautyfacts.org/ingredients.json

##### Products where the current experimental parser could not detect aluminium salts
* https://world.openbeautyfacts.org/ingredient/-aluminum-salts.json

##### Products where the current experimental parser could detect aluminium salts
* https://world.openbeautyfacts.org/ingredient/aluminum-salts.json

#### Periods after Opening
[https://en.wiki.openbeautyfacts.org/Global_period_after_opening_taxonomy Periods after opening taxonomy]

