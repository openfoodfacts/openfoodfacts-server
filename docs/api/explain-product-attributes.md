# Explanation on Product Attributes

## Introduction

Product Attributes is a way to query the Open Food Facts API to make it easier for clients (like apps but also the OFF website) to filter and rank search results according to user preferences, and to explain to users how well the products match their preferences.

The Product Attributes were introduced to support [Project:Personalized Search](https://world.openfoodfacts.org/project/personalized-search), but they enable many more uses.

## What it is

Product Attributes is a standardized way to get information on how well a product matches a given requirement (for instance: the product has good nutritional quality, it is vegetarian, does not contain eggs, is organic, etc.). The information is available as machine-readable data (e.g. 100% match) and internationalized human-friendly data ("This product has Nutri-Score E, it is recommended to reduce your consumption of products graded D and E"). For both the machine-readable and the human-friendly data, the format of the data is always the same for all requirements.

The machine-readable data makes it easy for apps to filter and rank search results in their own way, or according to the preferences of users.

The human-friendly data makes it easy to present the information to users, with translations.

## Benefits

Product Attributes greatly simplify how apps can use and display product information, while at the same time offering more flexibility.

- Apps don't have to add special code to process each type of requirement (e.g. looking at the array of ingredients and additives, the values of nutrients, etc.).
- Apps don't need to load and update taxonomies to interpret the returned data.
- Translations are managed by the server, and we can use Crowdin to crowdsource them in many languages.
- If desired, apps can decide to use new product attributes added on the server without requiring app changes.

## Current list of available Product Attributes

Product Attributes are organized in sections:

- Nutritional quality
  - Nutri-Score (A = 100%, E = 0%)
  - Low salt / Low sugar / Low fat / Low saturated fat (based on the Nutrition Traffic Lights): 1 product attribute for each so that users who are concerned only by salt can specify it.
- Transformation
  - No ultra-processed foods (NOVA 1 & 2 = 100%, 4 = 0%)
  - Few additives (0 additives = 100%)
- Allergens
  - For each allergen (not present = 100%, present = 0%, traces = 20% (low threshold that will exclude products if "No [allergen]" is marked as mandatory by the user)
- Ingredients
  - Vegan
  - Vegetarian
  - Palm oil
  - Unwanted/Banned ingredients (user-specified list of ingredients to avoid; requires API v3.4+)
- Labels
  - Organic
  - Fair trade
- Environment
  - Green-Score
  - Forest Footprint

New Product Attributes can be added over time.

## API

### List and descriptions of available product attributes

Apps can get the list of all available product attributes at the `/api/v3.4/attribute_groups` endpoint for API v3,
or at the `/api/v2/attribute_groups` or `/api/v2/attribute_groups_[language code]` endpoints for API v2.

e.g. [https://world.openfoodfacts.org/api/v3.4/attribute_groups]

Note that API < 3.4 does not support product attributes with parameters (such as the "Unwanted ingredients" attribute that requires a list of unwanted ingredients).

It returns a JSON array of attribute groups that each contain an array of attributes.

For a complete and accurate documentation refers to OpenAPI specification for v3.

Attribute groups keys:
- id - e.g. nutritional_quality
- name - e.g. Nutritional quality
- warning (optional)
- attributes: array of attributes

Attributes keys:
- id - e.g. "nutriscore",
- name - e.g. Nutri-Score"
- setting_name - e.g. "Good nutritional quality (Nutri-Score)" (in the form of a requirement)
- setting_note (optional) - e.g. extra detail that can be shown in user preferences
- parameters (optional, for some attributes like Unwanted ingredients that can be configured by the user)
  - array of parameters
    - id: parameter id (e.g. unwanted_ingredients_tags)
    - name: name of the parameter, to be displayed to users
    - type: "tags" indicate the parameter expects a comma separated list of canonical tags
    - tagtype: e.g. "ingredients" (for the "tags" type)

### Request

Apps can request Product Attributes through API queries (`/api/v3/product` or `/api/v2/search`) by including `attribute_groups` or `attribute_groups_[language code]` (or `attribute_groups_data` to get only the machine-readable data) in the `fields` parameter.

#### Product Attributes with Parameters (e.g. Unwanted/Banned ingredients)

In September 2024, we introduced support for attributes that can be configured with parameters. The first is the **Unwanted ingredients** attribute (also referred to as "banned ingredients" in cosmetics contexts) that takes a list of canonical ingredients as a parameter.

This feature is available on both:
- **Open Food Facts** (food products): for filtering out unwanted ingredients based on dietary preferences, allergies, or personal choices
- **Open Beauty Facts** (cosmetic products): for identifying banned or unwanted ingredients in cosmetics

In order not to break existing clients, this attribute is listed in the response of the API `/api/v3.4/attribute_groups` only when the version is at least 3.4:

```json
{
  "icon_url": "http://static.openfoodfacts.localhost/images/attributes/dist/contains-unwanted-ingredients.svg",
  "id": "unwanted_ingredients",
  "name": "Unwanted ingredients",
  "parameters": [
    {
      "id": "attribute_unwanted_ingredients_tags",
      "name": "Unwanted ingredients",
      "tagtype": "ingredients",
      "type": "tags"
    }
  ],
  "setting_name": "Unwanted ingredients",
  "values": [
    "not_important",
    "important",
    "very_important",
    "mandatory"
  ]
}
```

The response above indicates that the **Unwanted ingredients** attribute needs a `attribute_unwanted_ingredients_tags` parameter which is a list of comma separated canonical ingredients tags (e.g. "en:garlic,en:kiwi")

##### Sending unwanted/banned ingredients in requests

This parameter can be sent in product read and search requests in 2 ways:
- as a cookie with the name `attribute_unwanted_ingredients_tags`: this is used in particular on the website so that we do not have URLs with an extra query parameter.
- as a query parameter in the URL (e.g. ?attribute_unwanted_ingredients_tags=en:garlic,en:kiwi)

##### Getting ingredient suggestions

To help users identify ingredients to flag as unwanted/banned, you can use the **Robotoff API** to get ingredient predictions and suggestions:

1. **Get ingredient predictions from images**: Use Robotoff's OCR capabilities to extract ingredients from product images
   - API endpoint: `https://robotoff.openfoodfacts.org/api/v1/insights/{barcode}?insight_types=ingredient`
   - See [Robotoff API documentation](https://openfoodfacts.github.io/robotoff/references/api/) for details

2. **Browse ingredients taxonomy**: Use the ingredients taxonomy to help users discover ingredient tags
   - Endpoint: `https://world.openfoodfacts.org/data/taxonomies/ingredients.json`
   - Or search for specific ingredients via the API

3. **Autocomplete ingredient search**: Help users find canonical ingredient tags by name
   - Use the taxonomy search to find ingredients by their common names in different languages

##### Example usage

**Example 1: Checking a product for unwanted ingredients (Food)**

```bash
# Check if a product contains garlic or kiwi
curl "https://world.openfoodfacts.org/api/v3/product/3017620422003?fields=attribute_groups&attribute_unwanted_ingredients_tags=en:garlic,en:kiwi"
```

**Example 2: Checking cosmetic products for banned ingredients**

```bash
# Check a cosmetic product on Open Beauty Facts
curl "https://world.openbeautyfacts.org/api/v3/product/3600550448000?fields=attribute_groups&attribute_unwanted_ingredients_tags=en:parabens,en:sulfates"
```

**Example 3: Using cookies for persistent preferences**

```bash
# Set a cookie with unwanted ingredients
curl -b "attribute_unwanted_ingredients_tags=en:garlic,en:palm-oil" \
  "https://world.openfoodfacts.org/api/v3/product/3017620422003?fields=attribute_groups"
```

##### Understanding the response

When unwanted ingredients are specified, the API will return an `unwanted_ingredients` attribute in the response with:
- **status**: "known", "unknown", or "not-applicable"
- **match**: 
  - `0`: At least one unwanted ingredient is present
  - `100`: None of the unwanted ingredients are present
- **title**: Human-readable title (e.g., "Contains unwanted ingredients" or "No unwanted ingredients")
- **description_short**: List of found unwanted ingredients or confirmation message
- **description**: Detailed explanation with the list of ingredients checked

Example response when unwanted ingredient is found:
```json
{
  "id": "unwanted_ingredients",
  "name": "Unwanted ingredients",
  "status": "known",
  "match": 0,
  "title": "Contains unwanted ingredients",
  "description_short": "Garlic",
  "description": "Unwanted ingredients: Garlic",
  "icon_url": "https://static.openfoodfacts.org/images/attributes/dist/contains-unwanted-ingredients.svg"
}
```

Example response when no unwanted ingredients are found:
```json
{
  "id": "unwanted_ingredients",
  "name": "Unwanted ingredients", 
  "status": "known",
  "match": 100,
  "title": "No unwanted ingredients",
  "description_short": "We did not detect the following ingredients: Garlic, Kiwi",
  "icon_url": "https://static.openfoodfacts.org/images/attributes/dist/no-unwanted-ingredients.svg"
}
```

##### Platform-specific considerations

**For Open Food Facts (food products):**
- Common use cases include dietary restrictions (e.g., avoiding allergens, specific ingredients for religious reasons)
- Ingredients are matched against the ingredients taxonomy which includes common food ingredients

**For Open Beauty Facts (cosmetic products):**
- Common use cases include avoiding controversial cosmetic ingredients (e.g., parabens, sulfates, certain preservatives)
- Ingredients are matched against the cosmetic ingredients taxonomy
- Some jurisdictions have lists of banned ingredients in cosmetics that can be referenced

**For both platforms:**
- The feature requires that products have a complete ingredients list
- Unknown or unparsed ingredients may affect the accuracy of the detection
- If too many ingredients are unknown (>10% of total), the status will remain "unknown"

### Response

For each product returned, the corresponding field is added, containing an array of groups (to regroup attributes, like all allergens) that each contains an array of attributes.

#### Attribute group format

- id - e.g. nutritional_quality
- name - Name of the group of attributes e.g. "Nutritional quality"
- attributes - Array of attributes

#### Attribute format

- id - e.g. nutriscore
- name - e.g. "Nutri-Score"
- status - known, unknown, not-applicable: indicate if we have enough data to decide if the requirement is met
- match - 0 to 100 - indicate how well the product matches the requirement (100 = 100% match) 
- icon_url (optional)
- title - short title corresponding to the value of the attribute - e.g. "Nutri-Score D"
- details (optional) - explains how the match was computed, what triggered the match value (e.g. for vegan, list of ingredients that may not be vegan)
- description_short (optional) - very short description - e.g. "Bad nutritional quality"
- description (optional) - small text (1 or 2 paragraphs, possibly with bullet points introduced by dashes) - intended to be displayed under the description_short
- recommendation_short (optional) - "Reduce"
- recommendation_long (optional)
- official_link_title (optional) - "Nutri-Score page on Santé publique France"
- official_link_url (optional)
- off_link_title (optional)
- off_link_url (optional)

#### Example

- Request: https://world.openfoodfacts.org/api/v2/product/3700214614266?fields=product_name,code,attribute_groups_en
- Response (excerpt with only a few product attributes):

```json
{
    "status": 1,
    "code": "3700214614266",
    "status_verbose": "product found",
    "product": {
        "product_name": "Chocolat noir Pérou 90% fruité et boisé",
        "code": "3700214614266",
        "attribute_groups_en": [
            {
                "attributes": [
                    {
                        "status": "known",
                        "name": "Nutri-Score",
                        "match": 30,
                        "id": "nutriscore",
                        "title": "Nutri-Score D",
                        "description": "",
                        "description_short": "Poor nutritional quality"
                    }
                ],
                "name": "Nutritional quality",
                "id": "nutritional_quality"
            },
            {
                "id": "processing",
                "name": "Food processing",
                "attributes": [
                    {
                        "id": "nova",
                        "match": 50,
                        "name": "NOVA group",
                        "status": "known",
                        "description_short": "Processed foods",
                        "description": "",
                        "title": "NOVA 3"
                    }
                ]
            },
            {
                "id": "labels",
                "name": "Labels",
                "attributes": [
                    {
                        "title": "Organic product",
                        "description_short": "Promotes ecological sustainability and biodiversity.",
                        "description": "Organic farming aims to protect the environment and to conserve biodiversity by prohibiting or limiting the use of synthetic fertilizers, pesticides and food additives.",
                        "name": "Organic farming",
                        "match": 100,
                        "status": "known",
                        "id": "labels_organic"
                    },
                    {
                        "id": "labels_fair_trade",
                        "match": 100,
                        "name": "Fair trade",
                        "status": "known",
                        "description_short": "Fair trade products help producers in developing countries.",
                        "description": "When you buy fair trade products, producers in developing countries are paid a higher and fairer price, which helps them improve and sustain higher social and often environmental standards.",
                        "title": "Fair trade product"
                    }
                ]
            }
            // Actual response contains many more attribute, showing only a small excerpt here
        ]
    }
}
```

## Example uses

### Personalized search

On the client, users are being asked to enter preferences for each attribute (or a specific subset of attributes), for instance:

- The product is vegetarian - [ ] Not important, [ ] Important, [ ] Very important, [ ] Mandatory.

Based on the users preferences and the `match` key of the Product Attributes, apps can exclude some results (e.g., if a mandatory requirement is not fully met) and re-rank search results.

For each attribute, the server computes a match that goes from 0 to 100 (perfect match).

The filtering and ranking is done on the client, the preferences are not sent to the server.

Client-side (used in the Open Food Facts website and mobile app) algorithm to compute a user-defined sort key:

- For each requirement in user preferences:
  - If requirement is mandatory, score = score + match * 4
    - And exclude product if match is less than 20%
  - If requirement is very important, score = score + match * 2
  - If requirement is important, score = score + match

### Information and recommendations

Apps can use the returned human-friendly data of each attribute to show some explanations and/or recommendations to users.

As the data is always returned in the same format for each attribute, apps can also decide to display all product attributes returned by the API (even if the app is not aware of them).

Apps can also decide to display some attributes in their own way (using the more attribute-specific data that is returned by other fields in the API).

#### Possible display

Apps can display the attribute icon (that depends on both the attribute type and on how well the product matches the requirement) + the attribute short descriptions and recommendation, with an easy way to display the longer descriptions, recommendations, and links.

Attributes icons should be cached if possible (and apps could also pre-cache existing icons in the install package).

### Personalized information and recommendations

Based on users preferences, apps can filter and/or re-order the product attributes to first show the information that the user is the most interested in.

Apps can decide to keep the sections of attribute groups (e.g., keeping all allergens together) or not. In the former case, apps would thus first reorder the sections, and then the attributes in each section.



