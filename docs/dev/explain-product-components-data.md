# Explanation on product components data (multi-food packages)

This document explains the functional and technical specifications for representing multi-food packages (e.g. variety packs, meal kits, salad + dressing sachet kits) using the product components array in Open Food Facts.

## Introduction & Use Cases

Food packages often contain multiple distinct food items with separate nutrition tables, ingredients lists, or portion sizes. Examples include:

- **Variety Packs**: A pack of yogurt containing 3 different fruit flavors (e.g., strawberry, peach, blueberry) each with distinct ingredients and nutritional values.
- **Meal Kits / Sachet Kits**: A meal kit containing a main item (e.g., noodles or vegetables) and separate sachet components (e.g., seasoning packet, glaze, sauce).
- **Salad Kits**: A bag of greens with separate dressing and topping sachets.
- **Assortments / Advent Calendars**: Boxes with different chocolates or biscuits.

Single-level nutrition tables and ingredients lists cannot accurately represent these multi-component items without losing granular data.

---

## Functional Specifications

### 1. Data Model & Hierarchy

The top-level product object represents the overall physical package (identified by barcode `code`).

- **Top-level product fields**: Barcode (`code`), brands (`brands`), categories (`categories_tags`), overall packaging structure (`packagings`), and combined product metadata.
- **Product `components` field**: An array of component objects representing individual sub-items inside the package.

### 2. Attributes of a Component Item

Each object in the `components` array can contain the following attributes:

| Attribute | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `name` | String | Name or description of the sub-component | `"Liquid Gold Glaze"` |
| `quantity` | String | Net weight or portion quantity | `"14g"` |
| `serving_size` | String | Serving size specific to the sub-component | `"1 tbsp (14 g)"` |
| `ingredients_text` | String | Raw ingredients text for this component | `"Water, vegetable oil, sugar, salt"` |
| `ingredients` | Array | Structured parsed ingredients for this component | `[{"id": "en:water"}, ...]` |
| `nutriments` / `nutrition` | Object | Nutritional values for 100g or per serving of this component | `{"energy-kcal": 70, "fat": 6, "sodium": 270}` |
| `allergens_tags` | Array | Taxonomized allergen tags for this component | `["en:soybeans"]` |

### 3. API Read Behavior

- **Endpoint**: `GET /api/v3/product/{code}`
- **Query Parameter**: `fields=components` (or default `fields=all`).
- **Isolation**: Customization returns a deep clone (`dclone`) of the stored components array to protect internal memory state from client or handler mutations.

### 4. API Write Behavior

- **Endpoint**: `PATCH /api/v3/product/{code}`
- **Request Body Fields**:
  - `components`: Replaces the existing `components` array with the newly provided list.
  - `components_add`: Appends new component items to the pre-existing `components` array.
- **Validation Rules**:
  - If `components` or `components_add` is not an array reference, the API records error `invalid_type_must_be_array`.
  - If any element in the array is not an object (hash reference), the API records error `invalid_type_must_be_object`.

---

## Technical Specifications & OpenAPI v3 Integration

### 1. Perl API Layer Implementation

- `lib/ProductOpener/API.pm`:
  - `customize_components($request_ref, $product_ref)`: Processes and deep-clones product components for API output.
  - `customize_response_for_product(...)`: Includes `components` when requested by API clients.
- `lib/ProductOpener/APIProductWrite.pm`:
  - `update_components($request_ref, $product_ref, $field, $add_to_existing_components, $value)`: Handles writing (`components`) and appending (`components_add`).
  - `update_product_fields(...)`: Dispatches `components` and `components_add` fields.

### 2. OpenAPI v3 Specification

- **Schema definition**: `docs/api/ref/schemas/components/component.yaml`
- **Write schema definition**: `docs/api/ref/schemas/components/component-write.yaml`
- **Product integration**: `docs/api/ref/schemas/product_v3.yaml` and `docs/api/ref/schemas/product_update_api_v3.yaml`

---

## Unit Testing & Quality Assurance

Comprehensive unit test coverage is implemented in `tests/unit/components.t`, validating:
- Structure customization and deep-copy isolation.
- `customize_response_for_product` filtering (inclusion when requested, exclusion when omitted).
- Write API persistence (`components` replace vs `components_add` append).
- Type validation & structured error generation.
- Code formatting and linting (`perltidy` and `perlcritic`).
