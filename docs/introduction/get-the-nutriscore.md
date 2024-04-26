
### Introduction
-   If you can't get the information on a specific product, you can get your user to send photos and data, that will then be processed by Open Food Facts AI and contributors to get the computed result you want to show them.
-   You can implement the complete flow below so that they get immediately the result with some effort on their side.
-   That will ensure user satisfaction

### Display Nutri-Score knowledge panels - All the logic below in 5 lines of code !
- The Knowledge Panels are already implemented in the Dart package
- They are simple to implement from the JSON API
- They allow you to consume present and future knowledge from Open Food Facts

### Using the official visual assets of the Nutri-Score

use the official assets to display de nutriscore. You can get v1 logos here: [NutriScore variants](https://drive.google.com/drive/u/1/folders/13SL2hgqYHSLMhYjMze9nYXV9GOdGMBgc)

### Getting ready for Nutri-Score V2
- Nutri-Score V2 has a new computation method, which now requires the ingredient list, a category, and of course the nutrition table
- It also has a transition period new logo, to indicate you are using the new computation. It is not compulsory to use it, but it will save you from a lot of questions from your users ("Do you have the new formula ?")
- You can get the new assets by contacting reuse@openfoodfacts.org. We will make them public as soon as possible.

### Manual version: Getting the Nutri-Score v1 value (we don't recommand the manual way anymore, especially with v2 around the corner)

### Data completion flow

Here are the different messages to use according to the state:

#### Add a message if we have a category but no Nutri-Score

<pre>if "en:categories-completed" in states_tags AND nutrition_grade=Null</pre>

<pre>"We could not compute an Nutri-Score for this product. It might be that the category is an exception. If you believe this is an error, you can email contact@thenameofyourapp.org"</pre>

-   List of exceptions: <https://www.santepubliquefrance.fr/content/download/150262/file/QR_scientifique_technique_150421.pdf>
-   You can get states with [https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade,states_tags ](https://world.openfoodfacts.org/api/v0/product/3414280980209.json?fields=ecoscore_grade,states_tags)

#### Add a message if we have a category but no nutrition

<pre>if "en:categories-completed" in states_tags  AND "en:nutrition-facts-to-be-completed" in states_tags</pre>pre>

-   Prompt: "Add nutrition facts to compute the Nutri-Score"

-   Add a one-click option to indicate no nutrition facts on the packaging
  -   "This product doesn't have nutrition facts"

#### Add a message if we have nutrition but no category

<pre>if "en:categories-to-be-completed" in states_tags AND "en:nutrition-facts-completed" in states_tags</pre>

-   Prompt: "Add a category to compute the Nutri-Score"

#### Help the user add the category if it is missing

-   You can use our Robotoff API to get your users to validate a prediction

-   [Robotoff Questions](https://docs.google.com/document/d/1IoDy0toQrrqtWHvDYp2rEVw84Yq1J0x2pt-0RGTm7h0/edit)

#### Add a message if we have no category and no nutrition

<pre>if "en:categories-to-be-completed" in states_tags  AND "en:nutrition-facts-to-be-completed" in states_tags</pre>

-   Prompt: "Add nutrition facts and a category to compute the Nutri-Score"

#### Add a one-click option to indicate no nutrition facts on the packaging

-   This product doesn't have nutrition facts

#### Add a message if the nutrition image is missing

<pre>if "en:nutrition-photo-to-be-selected" in states_tags OR "en:photos-to-be-uploaded" in states_tags</pre>

#### Add a message if the nutrition image is obsolete using the image refresh API

-   <https://github.com/openfoodfacts/api-documentation/issues/15>

#### Add Nutri-Score disclaimers

##### a message if fibers are missing
<pre>
msgctxt "nutrition_grade_fr_fiber_warning"
msgid "Warning: the amount of fiber is not specified, their possible positive contribution to the grade could not be taken into account."
</pre>
##### a message if fruit/nuts are missing
<pre>
msgctxt "nutrition_grade_fr_no_fruits_vegetables_nuts_warning"
msgid "Warning: the amount of fruits, vegetables and nuts is not specified, their possible positive contribution to the grade could not be taken into account."
</pre>
##### a message if fruits/nuts is an estimate from ingredients
<pre>
msgctxt "nutrition_grade_fr_fruits_vegetables_nuts_estimate_warning"
msgid "Warning: the amount of fruits, vegetables and nuts is not specified on the label, it was estimated from the list of ingredients: %d%"
</pre>
##### a message if fruits/nuts is an estimate from category
<pre>
msgctxt "nutrition_grade_fr_fruits_vegetables_nuts_from_category_warning"
msgid "Warning: the amount of fruits, vegetables and nuts is not specified on the label, it was estimated from the category (%s) of the product: %d%"
</pre>
