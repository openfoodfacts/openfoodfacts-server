# Search API Documentation

This guide provides comprehensive documentation for the Open Food Facts Search API, including detailed information about filters, pagination, and usage examples.

> **Note:** The Search API v2 does NOT support full-text search. For full-text search capabilities, use [Search API v1](https://wiki.openfoodfacts.org/API/Read/Search).

## Overview

The Search API v2 allows you to search and filter products from the Open Food Facts database using various criteria. It supports:

- **Filter-based searches** using product attributes
- **Tag-based filtering** for categories, brands, labels, allergens, and more
- **Nutrient-based filtering** with comparison operators
- **Result pagination** for handling large result sets
- **Sorting** by various product attributes
- **Field limiting** to reduce response size

## Base Endpoint

\\\
GET /api/v2/search
\\\

## Pagination Parameters

Pagination helps you manage large result sets efficiently. By default, the API returns 24 products per page.

### Parameters

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| \page\ | integer | 1 | No | Page number of results (starts at 1) |
| \page_size\ | integer | 24 | No | Number of products per page (max: 250) |

### Response Pagination Fields

The search response includes pagination metadata:

\\\json
{
  "count": 1629,
  "page": 1,
  "page_size": 24,
  "page_count": 68,
  "products": [],
  "skip": 0
}
\\\

### Pagination Example

\\\
https://world.openfoodfacts.org/api/v2/search?categories_tags=breakfast-cereals&page=2&page_size=50
\\\

## Filter Parameters

The Search API supports numerous filter parameters to narrow down results. Most filters use tag-based filtering with parameters ending in \_tags\.

### Common Filter Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| \dditives_tags\ | Filter by food additives | \en:e150a\ |
| \llergens_tags\ | Filter by allergens | \en:gluten,en:peanuts\ |
| \rands_tags\ | Filter by product brand | \errero,nestle\ |
| \categories_tags\ | Filter by product category | \reakfast-cereals,dairy\ |
| \countries_tags\ | Filter by countries of origin | \en:france,en:spain\ |
| \emb_codes_tags\ | Filter by EMB codes | \r-75\ |
| \labels_tags\ | Filter by labels/certifications | \en:organic,en:fair-trade\ |
| \
utrition_grades_tags\ | Filter by Nutri-Score | \,b,c\ |
| \origins_tags\ | Filter by product origin | \en:france\ |
| \packaging_tags\ | Filter by packaging type | \en:plastic\ |
| \stores_tags\ | Filter by store names | \carrefour,leclerc\ |
| \	races_tags\ | Filter by allergen traces | \en:peanuts\ |

### Language-Specific Parameters

For many tag parameters, you can specify the language code:

- \categories_tags_en\ - English category tags
- \categories_tags_fr\ - French category tags
- \rands_tags_en\ - English brand tags

### Tag-Based Filter Syntax

Tag-based parameters accept multiple values using operators:

**Single Value:**
\\\
labels_tags=en:organic
\\\

**AND Operation (Comma):**
\\\
labels_tags=en:organic,en:fair-trade
\\\

**OR Operation (Pipe):**
\\\
labels_tags=en:organic|en:fair-trade
\\\

**Exclusion (Dash):**
\\\
labels_tags=en:organic,-en:fair-trade
\\\

## Nutrition-Based Filters

Filter products by nutritional content with comparison operators.

### Syntax Examples

Per 100g:
\\\
sugars_100g<5
protein_100g>20
\\\

Per serving:
\\\
energy-kcal_serving<100
\\\

### Common Nutrient Parameters

| Parameter | Description |
|-----------|-------------|
| \energy-kj_100g\ | Energy in kilojoules |
| \energy-kcal_100g\ | Energy in kilocalories |
| \at_100g\ | Total fat |
| \sugars_100g\ | Sugars |
| \salt_100g\ | Salt |
| \protein_100g\ | Protein |
| \iber_100g\ | Dietary fiber |

### Comparison Operators

| Operator | Meaning |
|----------|---------|
| \<\ | Less than |
| \>\ | Greater than |
| \=\ | Exact match |

## Sorting

Use the \sort_by\ parameter to order results:

\\\
sort_by=last_modified_t
sort_by=scans_n
\\\

## Field Selection

Use the \ields\ parameter to limit which attributes are returned:

\\\
fields=code,product_name,nutrition_grades
\\\

## Example Requests

### Example 1: Organic Cereals

\\\
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=breakfast-cereals&labels_tags=en:organic&fields=code,product_name,brands,nutrition_grades
\\\

### Example 2: Low-Sugar Dairy

\\\
https://world.openfoodfacts.org/api/v2/search?categories_tags=dairy&sugars_100g<5&page_size=50&fields=code,product_name
\\\

### Example 3: Pagination

\\\
https://world.openfoodfacts.org/api/v2/search?categories_tags_en=orange-juice&page=2&page_size=25
\\\

## Example Response

\\\json
{
  "count": 1629,
  "page": 1,
  "page_size": 24,
  "page_count": 68,
  "products": [
    {
      "code": "3123340008288",
      "product_name": "Orange Juice",
      "brands": "Fresh Fields",
      "nutrition_grades": "c"
    }
  ],
  "skip": 0
}
\\\

## Rate Limiting

The Search API is rate-limited to **10 requests per minute** per IP address. Do NOT use it for search-as-you-type features.

## Best Practices

1. Use the \ields\ parameter to specify only needed attributes
2. Implement pagination with appropriate \page_size\ values
3. Combine multiple filters to reduce result size
4. Respect the 10 requests per minute rate limit
5. Cache results locally when possible
6. Use language codes for consistent filtering

## Further Resources

- [Complete API Reference](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v2/)
- [Tutorial: Using the Open Food Facts API](./tutorial-off-api.md)
- [Search API v1 (Full-Text Search)](https://wiki.openfoodfacts.org/API/Read/Search)
- [FAQ - API Questions](https://support.openfoodfacts.org/help/en-gb/12-api)

## Need Help?

- **Questions?** Join our [Slack Community](https://slack.openfoodfacts.org/) (#api channel)
- **Found a bug?** [Report on GitHub](https://github.com/openfoodfacts/openfoodfacts-server/issues/new)
- **Feature request?** [Submit an issue](https://github.com/openfoodfacts/openfoodfacts-server/issues/new)
