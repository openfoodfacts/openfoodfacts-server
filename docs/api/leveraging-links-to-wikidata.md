#### How to leverage links to Wikidata (and Wikipedia) {#link_to_wikipedia_and_wikidata}
- You may have spotted things like https://www.wikidata.org/wiki/Q40050 in API outputs, especially those related to Taxonomies
- Whenever possible, Open Food Facts entities are linked to Wikidata,and in turn to Wikipedia. What this means is that you get access to a trove of additional encyclopedic knowledge about food. You can for instance get: Wikipedia articles about Camembert, the translation of salt in many languages, the molecular structure of a cosmetic ingredient...\
- We provide the Wikidata QID, which is an unambiguous, stable and reliable identifier for a concept that will be useful to actually retrieve info from Wikipedia and Wikidata.

##### Example
<https://world.openfoodfacts.org/categories.json>
{"linkeddata":{"wikidata:en":"Q40050"},"url":"https://world.openfoodfacts.net/category/beverages","name":"Beverages","id":"en:beverages","products":14196}
Beverages \>\> <https://world.openfoodfacts.org/category/beverages> \>\> Q40050 \>\> <https://www.wikidata.org/wiki/Q40050>\
As you see, you\'ll get a beautiful image, information about the Quality label... As Wikidata is a Wiki, the knowledge you\'ll be able to retrieve will increase over time.

#### Retrieving info from Wikipedia and Wikidata {#retrieving_info_from_wikipedia_and_wikidata}

You can use the Wikipedia and Wikidata APIs to get the information you want\
\* <https://www.wikidata.org/wiki/Wikidata:Data_access>

-   <https://en.wikipedia.org/w/api.php>

#### Examples of things you can do {#examples_of_things_you_can_do}

-   Provide more context and more information about a specific Product, a Category of products, a Quality label, a Geography, a Brand, a Packaging material, an ingredient...

\* Perform checks or computations by mixing Wikidata information and Open Food Facts information (and possibly other APIs)
