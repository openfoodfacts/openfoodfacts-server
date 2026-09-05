# Plan: Analyze Ecobalyse food transformation processes for integration into OFF environmental scoring

Date: 2026-08-19
Author: Stéphane

Note: this plan and the corresponding research have been elaborated with the help of AI
(with free models available with the Kilo extension in VSCode: Step 3.7 Flash, Laguna S 2.1, Hy3).

## Goal

1. Read `external-data/ecobalyse/processes.json` and extract all items whose
   `categories` array contains the value `"transformation"`.
2. Filter the result to food-related scopes (`food` and `food2`).
3. For each matching item, extract key fields: `activityName`, `displayName`,
   `id`, `ecs` (nested under `impacts.ecs`), `scopes`, `unit`, `source`,
   `elecKwh`, `heatMJ`.
4. Design a taxonomy-based approach to map OFF categories and ingredients
   processing to Ecobalyse transformation processes, leveraging the existing
   `ingredients_processing.txt` taxonomy and `categories.txt` properties.
5. Document the findings, challenges, and proposed implementation strategy.

## Data source

`processes.json` is the original Ecobalyse data file and must NOT be committed to this
repository. It is downloaded from:

https://github.com/MTES-MCT/ecobalyse/blob/master/public/data/processes.json

It is excluded from version control via `.gitignore` (see `external-data/ecobalyse/.gitignore`).

## Source data: `external-data/ecobalyse/processes.json`

- JSON array of **3132** items.
- Items with `"transformation"` in their `categories` array:
  - **25** items total with `"transformation"` as a category
  - **22** of those are `"textile"` scope (textile transformation processes)
  - **3** items with exact `categories: ["transformation"]` and `scopes: ["food"]`
  - **3** items with exact `categories: ["transformation"]` and `scopes: ["food2"]`
  - **9** items with `categories: ["transformation", "material_type:*"]` and `scopes: ["food2"]`

### Food transformation processes found

#### Exact `categories: ["transformation"]` — Agribalyse 3.2 source

| # | activityName | displayName | scope | unit | ecs | elecKwh | heatMJ |
|---|-------------|-------------|-------|------|-----|---------|--------|
| 1 | Canning fruits or vegetables, industrial, 1kg of canned product {FR} U | Mise en conserve | food | kg | 19.54 | 0 | 0 |
| 2 | Cooking, industrial, 1kg of cooked product {FR} U | Cuisson | food | kg | 17.42 | 0 | 0 |
| 3 | [Dummy] Mixing, processing, at plant {FR} U | Mélange | food | kg | 0 | 0 | 0 |
| 4 | Canning fruits or vegetables, industrial, 1kg of canned product {FR} U | Mise en conserve | food2 | kg | 19.54 | 0 | 0 |
| 5 | Cooking, industrial, 1kg of cooked product {FR} U | Cuisson | food2 | kg | 17.42 | 0 | 0 |
| 6 | [Dummy] Mixing, processing, at plant {FR} U | Mélange | food2 | kg | 0 | 0 | 0 |

Notes:
- Items 1 and 4 have identical ECS (19.54) and identical `activityName` — they differ only by scope (`food` vs `food2`).
- Items 2 and 5 have identical ECS (17.42) and identical `activityName` — they differ only by scope.
- Items 3 and 6 are dummy/empty entries with ECS = 0 (no data).
- All 6 are per-kg (`unit == "kg"`) generic transformation datasets.

#### Broader `categories: ["transformation", "material_type:*"]` — Ecobalyse_manual_lcia source (food2 only)

| # | displayName | material_type | scope | unit | ecs | elecKwh | heatMJ |
|---|-------------|---------------|-------|------|-----|---------|--------|
| 7 | Cuisson des abats | offal | food2 | kg | 0 | 0.7167 | 0.754 |
| 8 | Cuisson des céréales et féculents | cereals | food2 | kg | 0 | 0.7167 | 0.754 |
| 9 | Cuisson des fruits et légumes frais | fruits_and_vegetables | food2 | kg | 0 | 0.7167 | 0.754 |
| 10 | Cuisson des légumineuses | legumes | food2 | kg | 0 | 0.7167 | 0.754 |
| 11 | Cuisson des poissons et crustacées | fish_and_shellfish | food2 | kg | 0 | 0.7167 | 0.754 |
| 12 | Cuisson des viandes rouges | red_meats | food2 | kg | 0 | 0.7167 | 0.754 |
| 13 | Cuisson des volailles et viandes blanches | poultry | food2 | kg | 0 | 0.7167 | 0.754 |
| 14 | Cuisson des œufs | eggs | food2 | kg | 0 | 0.7167 | 0.754 |
| 15 | Cuisson divers | other_food_items | food2 | kg | 0 | 0.7167 | 0.754 |

Notes:
- All 9 are cooking processes specific to food material types.
- ECS = 0 for all (not yet computed or not applicable in this context).
- All have the same energy consumption: elecKwh = 0.7167, heatMJ = 0.754 per kg.
- Source is `Ecobalyse_manual_lcia` (not Agribalyse 3.2).
- Only available for `food2` scope.

### Key differences from packaging processes

| Aspect | Packaging | Transformation (food) |
|--------|-----------|----------------------|
| Total items in processes.json | 3132 | 3132 |
| Items with target category | 616 (packaging) | 25 (transformation) |
| Food-scoped items | 592 (296 food + 296 food2) | 6 exact + 9 broader = 15 |
| Unit type | item (per-product) / kg (per-kg material) | kg (all per-kg) |
| Source datasets | Agribalyse 3.2 | Agribalyse 3.2 + Ecobalyse_manual_lcia |
| Food category info | Embedded in activityName | Embedded in material_type tag |
| Display name language | French | French |
| ECS values | Non-zero for all | 0 for many (dummy/manual) |

## Field mapping

| Desired output | Source in JSON |
|----------------|----------------|
| `activityName` | `activityName` |
| `displayName` | `displayName` |
| `id` | `id` (UUID string) |
| `ecs` | `impacts.ecs` (float) — nested under `impacts` |
| `scopes` | `scopes` (array, e.g. `["food"]`) |
| `unit` | `unit` (`"kg"`) |
| `source` | `source` (`"Agribalyse 3.2"` or `"Ecobalyse_manual_lcia"`) |
| `elecKwh` | `elecKwh` (float) |
| `heatMJ` | `heatMJ` (float) |
| `material_type` | from `categories` array, the `material_type:*` tag (if present) |

## Proposed approach: Taxonomy-based mapping

### Strategy

Since there are very few usable transformation processes (essentially 2 with
non-zero ECS: canning and cooking), a separate JSON extraction file is
unnecessary overhead. Instead, we use a **declarative taxonomy-based approach**
that stores transformation metadata directly in existing taxonomies and uses a
small inline lookup in Perl:

1. **Extend `ingredients_processing.txt`** with Ecobalyse-specific properties
   for processing types that have transformation impacts.
2. **Add `ingredients_processing:en:` property to `categories.txt`** for
   categories that inherently involve specific transformations.
3. **Use a small hardcoded hash in `EnvironmentalImpact.pm`** keyed by the
   transformation UUID to provide the full ECS/energy data at runtime.

### Step 1: Extend `ingredients_processing.txt`

The `ingredients_processing.txt` taxonomy already supports arbitrary properties
(e.g., `nova:en:`). We add properties to relevant entries:

```
ecobalyse_transformation:en: [UUID]
ecobalyse_transformation_name:en: [activityName]
ecobalyse_transformation_name:fr: [displayName]
```

For the current dataset, we add these to:

- `en: cooked, boiled` (line 2154) -> maps to "Cooking, industrial" (id: `a2836bb8-7f45-5cfa-bb00-8b38046291cf`)
- `en: canned` (line 3524) -> maps to "Canning fruits or vegetables" (id: `a83c94af-6e31-5599-8022-7ae795862a99`)

Example entry after modification:

```
en: cooked, boiled
...
ecobalyse_transformation:en: a2836bb8-7f45-5cfa-bb00-8b38046291cf
ecobalyse_transformation_name:en: Cooking, industrial, 1kg of cooked product {FR} U
ecobalyse_transformation_name:fr: Cuisson
```

### Step 2: Add `ingredients_processing:en:` to `categories.txt`

Categories that inherently involve a transformation get a comma-separated list
of `ingredients_processing` entries. This uses the same property-key pattern
as other category metadata (e.g., `food_groups:en:`, `pnns_group_2:en:`).

Examples:

```
en: Canned vegetables
ingredients_processing:en: en:canned

en: Cooked meats
ingredients_processing:en: en:cooked

en: Prepared meals
ingredients_processing:en: en:cooked
```

In practice, in Ecobalyse, Canning and Cooking seem exclusive (Canning includes Cooking as a sub-step), so we can assume that a product is either canned or cooked, not both.

But we should still support multiple transformations in case more are added in the future.
e.g. a product could be both cooked and frozen, and Ecobalyse may add a frozen transformation process later.

Example:

```
en: Frozen cooked meals
ingredients_processing:en: en:cooked, en:frozen
```

### Step 3: Runtime lookup in `EnvironmentalImpact.pm`

Add a function `get_ecobalyse_transformation_entries($product_ref)` that:

1. Checks the product's category for `ingredients_processing:en:`.
2. Collects all matched transformation UUIDs, deduplicates, and returns the
   corresponding entries from a small inline hash.

The transformation data is stored as a small hardcoded hash in Perl, keyed by
UUID. This avoids needing a separate JSON extraction file for only 2 entries
with real ECS values.

Note: for now, we only look at the processings associated with the product's category. In the future, we may also look at the product's ingredients and their processing tags, if we want to capture transformations that happen at the ingredient level. This seems to be the direction of the new food2 API in Ecobalyse.

### Step 4: Scale and aggregate

Since all transformation entries are per-kg (`unit == "kg"`), scale each
entry's `ecs` by the product's `product_quantity` (converted to kg). If a
product has multiple applicable transformations (e.g., canned then cooked),
sum their scaled impacts.

## Implementation plan

### 1. Extend `ingredients_processing.txt`

Edit `taxonomies/ingredients_processing.txt` to add Ecobalyse properties to
`en: cooked, boiled` and `en: canned` entries.

### 2. Extend `categories.txt`

Edit `taxonomies/food/categories.txt` to add `ingredients_processing:en:`
properties to relevant categories (canned foods, cooked meats, prepared
meals, etc.).

### 3. Implement transformation matching in `EnvironmentalImpact.pm`

Add `get_ecobalyse_transformation_entries()`:

1. Define a small hardcoded hash of transformation data keyed by UUID
   (the 2 Agribalyse entries with real ECS values).
2. For the product's categories, look up `ingredients_processing:en:` via
   `get_property("categories", $category_tagid, "ingredients_processing:en")`.
3. Collect unique transformation UUIDs, look up their full data in the hash,
   scale by `product_quantity`, and sum.

### 4. Unit tests

Create `tests/unit/ecobalyse_transformation_matching.t`:

| Test case | Scenario | Expected |
|-----------|----------|----------|
| `canned_vegetables` | Product in `en:canned-vegetables` | Matches canning transformation (ecs 19.54) |
| `cooked_meat` | Product in `en:cooked-meats` | Matches cooking transformation (ecs 17.42) |
| `no_transformation` | Product with no cooking/canning category | Returns empty list |

## Verification plan

1. `ingredients_processing.txt` parses correctly with new properties.
2. `categories.txt` parses correctly with new `ingredients_processing:en:` properties.
3. Unit tests pass for all 3 scenarios above.

