# Analysis: matching OFF product data to Ecobalyse distribution, consumption and processing

Date: 2026-10-13
Author: Stéphane

Note: this analysis and the corresponding changes have been elaborated with the help of AI (Claude Code).

## Goal

Review how OFF product data is turned into the Ecobalyse food API inputs for the
distribution, consumption (preparation) and processing (transformation) steps,
identify gaps, and fix the most impactful ones.

See also `ecobalyse_transformation_analysis.md` (original design of the processing mapping)
and `ecobalyse_packaging_analysis.md`.

## Ecobalyse API reference

From the Ecobalyse OpenAPI spec (`GET https://ecobalyse.beta.gouv.fr/api`, version 2.3.0):

### `/api/food` (FoodQuery) — currently used by OFF

| Field | Type | Values |
|-------|------|--------|
| `ingredients` | array, min 1 | `{id, mass}` (mass in grams) |
| `transform` | object, optional | `{id, mass}` — a single transformation process |
| `packaging` | array | `{id, mass}` |
| `distribution` | string enum | `ambient` (default), `fresh`, `frozen` — includes 450 km road transport to storage + 150 km to retail |
| `preparation` | array, max 2 items | `frying`, `pan-cooking`, `pan-warming`, `oven`, `microwave`, `refrigeration`, `freezing` |

`additionalProperties: false`: any unknown field or out-of-enum value makes the request fail.

### `/{scope}/simulator` (GenericQuery) — food2 scope

Completely different structure:

- `components` (each with `elements`, each element with a `material` and its own `transforms`)
- `product`: UUID of an Ecobalyse product category, which provides defaults for
  `consumptions`, `distribution` and `transportOptions.cooling`
- `distribution`: UUID of a distribution process (3 food2 processes in `processes.json`:
  "Vente au détail : produit frais / sec / surgelé")
- `consumptions`: UUIDs of use-phase processes (7 `productmassdependent` food2 processes in
  `processes.json`: Congélation, Réfrigération, Cuisson au four, Cuisson au four à micro-ondes,
  Cuisson à la poêle, Réchauffage à la poêle, Friture)

There is no top-level `transformations` field in GenericQuery.

### Transport cooling

Ecobalyse ingredients have a `transportCooling` property (`ingredients.json`):
`always` (1021), `none` (423), `once_transformed` (12: flour, sunflower oil, eggs, goat milk,
carrots, tomatoes, cocoa butter…). With `once_transformed`, refrigerated transport depends on
whether the recipe has a transformation, so the processing mapping also affects transport.

## Current OFF implementation (before this change)

`lib/ProductOpener/EnvironmentalImpact.pm`, `estimate_environmental_impact_service()`:

- **Distribution**: `storage_conditions` (set by `ProductOpener::StorageConditions` from the
  inherited `storage_conditions:en` category property), prefix stripped,
  `refrigerated` renamed to `fresh`, default `ambient`.
- **Consumption**: not sent at all, so the consumer stage contributes nothing.
- **Processing**: `get_ecobalyse_transformation_entries()` reads the `ingredients_processing:en`
  property of every category in `categories_tags`, maps it to the
  `ecobalyse_transformation:en` property of `ingredients_processing.txt`
  (cooking or canning), and the food API branch sends only the first entry.

## Findings

### 1. Distribution

**Low coverage.** Only 12 categories had a `storage_conditions:en` property
(canned foods, frozen foods, refrigerated foods, fresh meats, fresh vegetables, fresh fruits,
onions, potatoes, fresh tomatoes, frozen onions, frozen potatoes, frozen juices).
About 900 categories inherited a value; everything else defaulted to `ambient`, including:

- yogurts, cheeses, butters, fresh milks, dairy desserts, fresh creams
- hams, cooked hams, sausages, pâtés, rillettes, `en:cooked-meats`
- smoked salmon and other smoked fish
- fresh pasta, fresh meals, prepared salads, sushi, tofu, hummus

`en:refrigerated-foods` has only 7 descendants. Chilled products, for which the distribution
step matters most, were systematically under-estimated.

**Semi-preserved foods** are under `en:canned-foods`: they got `ambient` distribution and the
canning process, while they are refrigerated and not sterilized.

**Conflicting parents.** 15 categories inherit different values from different parents
(e.g. fresh onions: fresh vegetables = refrigerated, onions = ambient). The resolution
(`get_inherited_property`) is a breadth-first walk of the parents, sorted alphabetically at each
level, starting from the most specific category of the product: the nearest ancestor with the
property wins, and ties are broken alphabetically.

**No value validation.** Any value of `storage_conditions` other than ambient / refrigerated /
frozen (e.g. a new entry in `storage_conditions.txt`) would have been sent as-is and rejected
by the API.

**Product services API.** `set_storage_conditions()` is only called in the full product
processing pipeline (`Products.pm`). When `estimate_environmental_impact` is called through the
product services API (`APIProductServices.pm`), `storage_conditions` is missing and the
distribution was always `ambient`. This was visible in the unit tests:
`tests/unit/ecobalyse.t` / `fr-frozen-green-beans` sent `"distribution": "ambient"`.

**Traceability.** `set_storage_conditions()` discards the category that provided the value,
which makes mapping errors hard to spot.

### 2. Consumption (preparation)

Not implemented. Options:

- **Refrigeration / freezing** at the consumer can be derived directly from the storage conditions
  (refrigerated → `refrigeration`, frozen → `freezing`): no new data needed.
- **Cooking methods** need a new category property (e.g. `ecobalyse_preparation:en:`):
  frozen pizzas → `oven`; dry pasta, rice → `pan-cooking`; ready meals → `microwave`;
  frozen fries → `oven`; raw meat → `pan-cooking`…
- For food2: `consumptions` UUIDs (see above).

### 3. Processing (transformation)

Only 4 categories set `ingredients_processing:en`
(canned foods → canned, canned vegetables → canned, meals → cooked, cooked meats → cooked),
reaching about 1040 categories through inheritance.

- **Canned + cooked conflict** (14 categories: canned meals, canned soups, canned ravioli,
  canned veal, canned prepared salads…). The food API takes `$transformation_entries[0]`,
  which depends on the order of `categories_tags` (sorted by level, then alphabetically),
  not on intent. Canning already includes cooking, so canning should always win.
- **`en:meals` → cooked is too broad** (764 descendants): sashimi, meal replacements
  (powders / drinks), dough-based meals to be cooked by the consumer, raw prepared salads
  (coleslaw, cucumber salads…).
- **Overrides were impossible.** The property was read with `get_property` on every category
  of `categories_tags` (which includes all parents), so a child category could not cancel the
  value of a parent.
- **Canning process applied to all canned foods.** The Agribalyse process is
  "Canning fruits or vegetables"; it is used as a proxy for canned fish, meat, cheese and
  rice puddings. Acceptable, but should be documented as a proxy.
- **food2 branch would fail.** It sends a top-level `transformations` array plus `ingredients`,
  neither of which exist in GenericQuery (`additionalProperties: false`), and the URL is always
  `/api/food`. Dormant while `$ecobalyse_version = "food"`.
- **Duplicated process data**: UUIDs and names are in both `ingredients_processing.txt` and the
  hardcoded hash in `get_ecobalyse_transformation_entries()`. The `ecs` values in the hash are
  not sent and only appear in unit test outputs.
- **Transform mass** is the sum of the leaf ingredient quantities (including ingredients without
  an Ecobalyse id), which is correct for a per-100 g product. If no ingredient has a quantity,
  the mass is 0.

### 4. Tests

`ecobalyse_transformation_matching.t` only used single leaf categories, not real
`categories_tags` with parents, so the canned + meals conflict was not exercised.
No test covered the storage conditions → distribution mapping outside of the full pipeline.

## Changes made (branch `ecobalyse-distribution-consumption-processing`)

### Taxonomy: `taxonomies/food/categories.txt`

`storage_conditions:en: en:refrigerated` added to:

- dairy: `en:fermented-milk-products` (cheeses, quarks, fermented creams, buttermilks…),
  `en:dairy-desserts` (incl. yogurts), `en:butters`, `en:refrigerated-creams`,
  `en:refrigerated-milks`, `en:fresh-milks`, `en:pasteurised-milks`, `en:microfiltered-milks`
- meat and fish: `en:prepared-meats` (charcuterie), `en:cooked-meats`, `en:smoked-fishes`
- prepared foods: `en:fresh-pasta`, `en:fresh-meals`, `en:prepared-salads`,
  `en:sushi-and-maki`, `xx:sashimi`, `xx:tofu`, `en:hummus`
- `en:semi-preserved-foods`

`storage_conditions:en: en:ambient` added to `en:uht-creams`, `en:dried-meats`, and to canned
descendants of dairy desserts / prepared salads that would otherwise resolve to refrigerated
(`en:canned-creamy-puddings`, `en:canned-chocolate-creamy-puddings`,
`en:canned-semolina-puddings`, `en:canned-prepared-mixed-tuna-and-vegetable-salad`).

`storage_conditions:en: en:frozen` added to `en:frozen-spinach-young-leaves`
(closer refrigerated ancestor `en:fresh-vegetables`).

**Frozen categories linked to `en:frozen-foods`.** 163 frozen categories (`en:frozen-*`,
`*-surgele(e)s`, ice cream goblets) were not descendants of `en:frozen-foods`, and therefore
defaulted to ambient. Each was given an additional parent, the most specific existing frozen node:

| New parent | Categories | Examples |
|---|---|---|
| `en:frozen-meats` | 64 | frozen lamb, pork, veal, venison, rabbit, kangaroo cuts, merguez |
| `en:frozen-poultry` | 38 | frozen chickens, ducks, geese, turkey cuts, chicken nuggets, poultry skewers |
| `en:frozen-fishes` | 28 | frozen cod, salmon, tuna fillets, fish fingers |
| `en:frozen-seafood` | 21 | frozen shrimps, crabs, lobsters, mussels, squid, surimi |
| `en:frozen-desserts` | 4 | ice cream goblets |
| `en:frozen-ready-made-meals` | 2 | frozen pasta dishes, frozen meals with fish |
| `en:frozen-plant-based-foods` | 2 | frozen juices, poêlées sarladaises |
| `en:frozen-dumplings` | 1 | khinkali |
| `en:frozen-foods` | 3 | frozen crêpes, frozen offal soup, frozen foie gras |

8 entries referenced non-existent parents (`< en: Frozen Meat` ×7, all frozen duck categories, and
`< en: Frozen meals` ×1, frozen pasta dishes): these were replaced by the new parents.
Not linked (not frozen products): `en:cone-wafer-for-ice-cream`, and restaurant desserts containing
ice cream (`en:profiteroles-with-vanilla-ice-cream-and-chocolate-sauce`,
`en:peach-melba-with-vanilla-ice-cream-and-raspberry-sauce`).

After this change, every frozen-named category resolves to `en:frozen` (654 categories, up from ~480).

Result (simulation of the inheritance resolution on all categories):

| storage_conditions | before | after |
|---|---|---|
| refrigerated | 77 | ~2400 |
| frozen | ~480 | ~655 |
| ambient (explicit) | ~330 | ~360 |

**Fresh meat and fish.** Once the frozen categories were linked to `en:frozen-foods` (see below),
`storage_conditions:en: en:refrigerated` was also set on `en:meats`, `en:fishes`, `en:crustaceans`
and `en:shellfish`. Because the inheritance resolution breaks ties alphabetically
(`en:fishes` < `en:frozen-foods`), explicit `en:frozen` values were added to the intermediate
frozen nodes `en:frozen-meats`, `en:frozen-poultry`, `en:frozen-fishes`, `en:frozen-seafood`,
`en:frozen-crustaceans`, and to `en:frozen-cooked-jumbo-shrimps` and
`en:cooked-snails-in-parsley-butter` (sold frozen).
Explicit `en:ambient` overrides were added for shelf-stable descendants: `en:insects`, `en:snails`,
duck and goose confits, preserved gizzards and livers, `en:salted-dried-cod`,
`en:shelf-stable-prepared-shellfish`, `en:shelf-stable-unprepared-fishes`, canned fish entries that
are not under `en:canned-foods` (albacore, pilchards, cod liver), and fish fillets in oil
(anchovy, mackerel, sardine). Marinated anchovies, rollmops and pickled herring stay refrigerated.

`ingredients_processing:en: undef` (cancels the inherited value) added to `xx:sashimi`,
`en:meal-replacements`, `en:non-frozen-dough-based-meals-to-prepare`,
`en:frozen-dough-based-meals-to-prepare`, `en:prepared-salads`, `en:semi-preserved-foods`.
`ingredients_processing:en: en:cooked` added back to `en:pasta-salads`, `en:rice-salads`,
`en:potato-salads`, `en:lentil-salads`, `en:bulgur-salads`.

### Code: `lib/ProductOpener/EnvironmentalImpact.pm`

- **Distribution**: explicit mapping `en:ambient` → `ambient`, `en:refrigerated` → `fresh`,
  `en:frozen` → `frozen`, with `ambient` as fallback for unknown values.
  When `storage_conditions` is not set (product services API), the inherited
  `storage_conditions:en` category property is used directly.
- **Preparation**: `fresh` → `["refrigeration"]`, `frozen` → `["freezing"]`, sent in the payload
  and stored in `environmental_impact.ecobalyse_input.preparation`.
- **Processing** (`get_ecobalyse_transformation_entries()`):
  - the property of a category is ignored when a more specific category of the product
    (a descendant) also has the property, so that children can override parents;
  - the value `undef` means no processing;
  - properties of unrelated categories are combined;
  - canning supersedes cooking (canning includes cooking).

### Taxonomy linter: `scripts/taxonomies/lint_taxonomy.pl`

The linter canonicalized the special value `undef` of taxonomy-referencing properties to
`en:undef`, which disabled the "stop inheritance" semantics of `get_inherited_property()`.
`undef` is now kept as-is.

### Tests

- `tests/unit/ecobalyse_transformation_matching.t`: new cases with realistic `categories_tags`:
  `canned_soup` (canning only), `sashimi` (none), `semi_preserved_anchovies` (none),
  `coleslaw` (none), `pasta_salad` (cooking). `multiple_transformations` now returns canning only.
- `tests/unit/ecobalyse.t`: the expected payloads change (distribution / preparation for frozen
  green beans). The mocked Ecobalyse responses need to be regenerated with a real API token
  (`ECOBALYSE_API_TOKEN=... prove -v tests/unit/ecobalyse.t --update-expected-results`).

## Follow-ups (not done yet)

1. **Cooking methods at the consumer**: new category property (e.g. `ecobalyse_preparation:en:`)
   for oven / microwave / pan-cooking / frying, combined with refrigeration / freezing
   (max 2 preparation values).
2. **Judgement calls to review**: whole dry sausages (`en:dry-sausages`) and pâtés / rillettes are
   now refrigerated (often sold ambient in jars or as whole sausages); fresh fruits are ambient
   while fresh vegetables are refrigerated; eggs stay ambient.
3. **food2**: remove or rewrite the food2 branch (components / elements / transforms, UUID-based
   distribution and consumptions, `product` category defaults).
4. **Single source for process data**: read names / UUIDs from `ingredients_processing.txt`
   (or from an extracted JSON file) instead of the hardcoded hash.
5. **Traceability**: store the category that provided the storage conditions and the processing in
   `environmental_impact.ecobalyse_input`.
6. **Other processes**: Ecobalyse food has no freezing, drying or smoking transformation process;
   if they are added (food2 has material-type-specific cooking processes), the mapping in
   `ingredients_processing.txt` can be extended.
