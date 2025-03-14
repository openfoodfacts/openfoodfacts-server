# Reference: API and product schema change log

This reference lists changes to the API and/or the product schema.

## Introduction

The schema of product data in the Open Food Facts database changes over time:
- We often add new raw data fields (e.g. packaging data), or new computed fields (e.g. health and environmental scores).
- Occasionally, we refactor some fields to improve how we structure some data (e.g. in the beginning we had a flat list of ingredients, then we added a nested ingredients structure to better represent sub-ingredients).

We consider new fields to be non-breaking changes. When reading product data, make sure that your implementation will ignore new fields and not break.

We consider changed fields to be breaking changes. To maintain backward compatibility, we increase the API version number when there is a breaking change, and we try to serve the old structure when a lower API version is requested by a client.

## Product schema version

The product schema version is an integer that is incremented each time there is a change.
It was introduced in March 2025, with a value of 1001.
For products updated after March 2025, the product schema version is saved in the schema_version field of the product object.
For earlier products (or earlier product revisions), the product schema version is 1000 or below. It is not stored in the database, but it can be returned for API requests with an API version lesser than 3.2.

## API version

Since 2012, we have used API versions like 0, 1, 2, 3 and 3.1.
For each of those API version, we have a corresponding product schema version.

When a client makes a request with a specific API version, we do our best to convert the response to the corresponding product schema version.

## Schema version and API version change log

### 2025-03-12 - Product version 1001 - API version 3.2 - Removed ingredients_hierarchy, added schema_version

Breaking changes:
- ingredients_hierarchy array has been removed (its content is identical to the ingredients_tags array)

Non-breaking changes:
- added schema_version field

PR: https://github.com/openfoodfacts/openfoodfacts-server/pull/11615

### 2024-12-12 - Product version 1000 - API version 3.1 - Renamed ecoscore_* fields to environmental_score_*

Breaking changes:
- For legal reasons, we had to rename the Eco-Score to Green-Score. To make sure we won't have to update the schema again, we renamed the corresponding fields from ecoscore_* to the generic name environmental_score_*

### Warning: non-breaking changes not indicated in change logs below

There were lots of non-breaking changes (new fields) from 2012 to 2024. Those changes did not trigger a change to the API version, and their history has not been listed.

### Product version 999 - API version 3

Breaking changes:
- All v3 responses (including product READ requests that use the route /api/v3/product/[barcode]) follow the same structure to indicate status (success or failure), errors and warnings.
- The shape, material and recycling properties of each packaging component are localized: we return a hash with an id and a lc_name field, instead of just an id.

### Product version 998 - API version 2

Breaking changes:
- The ingredients structure is now a nested structure, with sub-ingredients in the "ingredients" field of each ingredient. Previously sub-ingredients were listed at the end of ingredients.

### Product version 997 - API version 1

Breaking changes:
- For product READ requests, if the product does not exist, we return HTTP status code 404 instead of 200.

### Product version 996 - API version 0