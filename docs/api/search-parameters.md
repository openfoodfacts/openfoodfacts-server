# Search API Filters & Pagination Guide

This guide provides comprehensive documentation for filtering and pagination parameters in the Open Food Facts Search API.

## Base Endpoint

```
GET /api/v2/search
```

## Quick Example

```
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=orange-juice&nutrition_grades_tags=c&page=1&page_size=20&fields=code,product_name,nutrition_grades
```

---

## Pagination

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | integer | 1 | The page number you request to view (e.g., in search results spanning multiple pages) |
| `page_size` | integer | 24 | The maximum number of products to return per page |

### Example

```
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=orange-juice&page=2&page_size=50
```

### Response Structure

```json
{
  "count": 1629,
  "page": 2,
  "page_count": 33,
  "page_size": 50,
  "skip": 50,
  "products": [
    {
      "code": "3123340008288",
      "product_name": "Orange Juice 100%",
      ...
    },
    ...
  ]
}
```

### Response Fields Explained

- **`count`**: Total number of products matching the search criteria (not just on this page)
- **`page`**: Current page number requested
- **`page_count`**: Maximum number of pages available for this search
- **`page_size`**: Number of items returned on this page
- **`skip`**: Number of items skipped (useful for offset-based pagination: `skip = (page - 1) × page_size`)

### Edge Cases

**Invalid Page Number:**
- Requesting `page=999` when only 33 pages exist will return an empty `products` array with `count` still showing total available matches

**Page Size Too Large:**
- Requesting `page_size=10000` may be rate-limited. Recommended maximum is `100-500` depending on your use case
- For bulk operations, use smaller page sizes or increase time between requests

**Zero or Negative Values:**
- `page=0` or `page=-1`: Behaves like `page=1`
- `page_size=0`: Uses default value of 24

---

## Tag-Based Filters

Tag filters allow you to search by categorical attributes. All tag parameters support **language suffixes** and **logical operators**.

### Tag Parameters

| Parameter | Description | Example Values |
|-----------|-------------|-----------------|
| `additives_tags` | Food additives and E-numbers | `en:e101`, `en:e122` |
| `allergens_tags` | Allergen information | `en:gluten`, `en:peanuts`, `en:milk` |
| `brands_tags` | Brand names | `ferrero`, `nestle`, `coca-cola` |
| `categories_tags` | Product categories | `cereals`, `beverages`, `snacks` |
| `countries_tags` | Country of origin/manufacture | `united-states`, `france`, `india` |
| `emb_codes_tags` | EMB (European packaging) codes | `fr-29-011-001`, `de-bw-00001` |
| `labels_tags` | Labels (organic, fair-trade, etc.) | `en:organic`, `en:fair-trade`, `en:vegan` |
| `manufacturing_places_tags` | Manufacturing locations | `france`, `china`, `germany` |
| `nutrition_grades_tags` | Nutri-Score grades | `a`, `b`, `c`, `d`, `e` |
| `origins_tags` | Origins of ingredients | `en:france`, `en:spain` |
| `packaging_tags` | Packaging materials/types | `plastic`, `glass`, `cardboard` |
| `purchase_places_tags` | Purchase locations | `supermarket`, `farmers-market` |
| `states_tags` | Product states | `en:organic`, `en:vegan` |
| `stores_tags` | Store names | `carrefour`, `aldi`, `whole-foods` |
| `traces_tags` | Allergen traces | `en:peanuts`, `en:tree-nuts` |

### Language Suffixes

Language codes can be appended to tag parameters to filter by language-specific taxonomy:

```
?categories_tags_en=orange-juice          # English category
?categories_tags_fr=jus-d-orange          # French category
?brands_tags_de=muller                    # German brand
```

### Logical Operators

#### AND Operator (Comma-Separated)

Returns products matching **all** conditions:

```
?labels_tags=en:organic,en:fair-trade
# Products that are BOTH organic AND fair-trade
```

#### OR Operator (Pipe-Separated)

Returns products matching **any** condition:

```
?nutrition_grades_tags=a|b
# Products with grade A OR B (higher quality scores)
```

#### NOT Operator (Minus Prefix)

Excludes products matching the condition:

```
?labels_tags=en:organic,-en:fair-trade
# Products that are organic BUT NOT fair-trade
```

### Examples

**Find vegan products in the Beverages category:**
```
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=beverages&labels_tags=en:vegan
```

**Find products from Ferrero OR Nestlé that are NOT made with additives:**
```
https://world.openfoodfacts.org/api/v2/search?brands_tags=ferrero|nestle&additives_tags=-en:e102,-en:e104
```

**Find cereals with Nutri-Score A or B:**
```
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=cereals&nutrition_grades_tags=a|b
```

---

## Nutrient Filters

Search products based on nutrition composition. Nutrients support **comparison operators** and **multiple base units**.

### Nutrient Filter Syntax

```
{nutrient_name}_{base}{operator}{value}
```

### Components

**Nutrient Name:** Chemical name of the nutrient
- `energy` (energy in kJ)
- `energy-kcal` (energy in kcal)
- `sugars` (sugar content)
- `saturated-fat`, `fat` (fat content)
- `salt`, `sodium` (salt content)
- `fiber` (dietary fiber)
- `protein` (protein content)
- See [Product Attributes Documentation](explain-product-attributes.md) for complete list

**Base:** Measurement unit/context
- `_100g` - Per 100g of product
- `_serving` - Per serving size
- `_prepared_` - For the prepared version of the product (cooked food)
  - Example: `sugars_prepared_100g`

**Operator:** Comparison type
- `<` - Less than (under)
- `>` - Greater than (above/over)
- `=` - Exactly equal to

### Examples

**Find products with less than 10g of sugar per 100g:**
```
https://world.openfoodfacts.org/api/v2/search?sugars_100g<10
```

**Find high-protein foods (>10g per serving):**
```
https://world.openfoodfacts.org/api/v2/search?protein_serving>10
```

**Find low-sodium products (<0.5g salt per 100g):**
```
https://world.openfoodfacts.org/api/v2/search?salt_100g<0.5
```

**Find beverages with less energy (< 200 kJ per 100g):**
```
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=beverages&energy-kj_100g<200
```

**Combine multiple nutrient filters (AND logic):**
```
https://world.openfoodfacts.org/api/v2/search?sugars_100g<10&fat_100g<5&protein_100g>2
```

### Important Notes

- **Exact Match:** Use `=` operator
  - `sugars_100g=5` returns products with exactly 5g sugar per 100g
- **Prepared Products:** Use `_prepared_` for cooked/processed products
  - Example: `energy-kj_prepared_100g<500`
- **Missing Data:** Products without nutrient information will not match nutrient filters

---

## Sorting Results

Control the order of returned products using the `sort_by` parameter.

### Sort Options

| Value | Sort By | Notes |
|-------|---------|-------|
| `product_name` | Product name (A-Z) | Alphabetical order |
| `popularity_key` | Popularity/scans | Most scanned products first (default if no sort specified) |
| `scans_n` | Number of scans | Total number of product scans |
| `unique_scans_n` | Unique scans | Number of unique users scanning the product |
| `created_t` | Creation date | Newest products first |
| `last_modified_t` | Last modified date | Recently updated products first |
| `nutriscore_score` | Nutri-Score ranking | Better grades first (A→E) |
| `ecoscore_score` | Eco-Score ranking | Better environmental score first |
| `nova_score` | NOVA food processing | Less processed products first |
| `completeness` | Data completeness | Most complete product information first |
| `nothing` | No sorting | Arbitrary order; useful for performance if sorting isn't needed |

### Examples

**Sort by product name:**
```
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=cereals&sort_by=product_name
```

**Find most recently added products:**
```
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=beverages&sort_by=created_t
```

**Sort by nutritional score (best scores first):**
```
https://world.openfoodfacts.org/api/v2/search?sort_by=nutriscore_score
```

---

## Response Limiting

Use the `fields` parameter to reduce response size and only retrieve needed data.

### Syntax

```
?fields=code,product_name,nutrition_grades,brands
```

### Common Fields

| Field | Description |
|-------|-------------|
| `code` | Product barcode/EAN |
| `product_name` | Name of the product |
| `brands` | Brand name(s) |
| `categories_tags_en` | Category tags (English) |
| `nutrition_grades` | Nutri-Score grade (A-E) |
| `nutriscore_score` | Nutri-Score numerical score |
| `energy` | Energy (kJ) |
| `nutriments` | Full nutrition facts object |
| `ecoscore_score` | Eco-Score value |
| `labels_tags_en` | Product labels (English) |
| `ingredients` | Ingredient list |
| `allergens` | Allergen information |

### Example

**Minimal response with only essential fields:**
```
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=orange-juice&fields=code,product_name,nutrition_grades&page_size=100
```

This reduces network bandwidth and API server load. **It is recommended to always use this parameter.**

---

## Complete Search Examples

### Example 1: Find healthy beverages

Find non-alcoholic beverages with good Nutri-Score (A or B) and low sugar:

```
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=non-alcoholic-beverages&nutrition_grades_tags=a|b&sugars_100g<5&fields=code,product_name,nutrition_grades,sugars_100g&page_size=50
```

### Example 2: Find organic fair-trade products

Find products that are both organic AND fair-trade:

```
https://world.openfoodfacts.org/api/v2/search?labels_tags=en:organic,en:fair-trade&sort_by=product_name&fields=code,product_name,brands&page=1&page_size=25
```

### Example 3: Find low-sodium snacks

Find snacks with minimal salt content:

```
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=snacks&salt_100g<0.3&sort_by=nutriscore_score&fields=code,product_name,salt_100g,nutrition_grades
```

### Example 4: Browse all products by recency

View products by when they were last updated:

```
https://world.openfoodfacts.org/api/v2/search?sort_by=last_modified_t&fields=code,product_name,last_modified_t&page=1&page_size=100
```

---

## Important Notes

### Rate Limiting

- No authentication required for search queries
- Include a `User-Agent` header identifying your app in all requests
- Recommended: 1-2 requests per second per IP

### Full-Text Search

**Important:** The v2 Search API **does not support full-text search** (search for arbitrary keywords in product names/descriptions).

For full-text search capabilities, use:
- [Search API v1](https://wiki.openfoodfacts.org/API/Read/Search)
- [Search-a-licious API](https://search.openfoodfacts.org/docs) (new, recommended, in beta)

### API Environments

- **Production:** `https://world.openfoodfacts.org/api/v2/search`
- **Staging:** `https://world.openfoodfacts.net/api/v2/search`

### Response Header Info

Always check responses for metadata:
```json
{
  "count": 1629,         // Total matching products (across all pages)
  "page": 1,             // Current page
  "page_count": 33,      // Total available pages
  "skip": 0              // Offset from start
}
```

---

## See Also

- [API Introduction](index.md)
- [API Cheatsheet](ref-cheatsheet.md)
- [API Reference (Interactive)](ref-v2.md)
- [Product Attributes Guide](explain-product-attributes.md)
- [Tutorial: Search for Products](tutorial-off-api.md#search-for-a-product-by-nutri-score)
