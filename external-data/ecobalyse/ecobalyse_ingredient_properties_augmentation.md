# Plan: Augment ingredients.txt taxonomy with Ecobalyse properties from ingredients.json

Date: 2026-09-09
Author: Stéphane, with the help of LLM models
Status: **IN PROGRESS** — Extraction script rewritten with correct naming convention (`ecobalyse:` / `ecobalyse_proxy:` prefix + variant + field); TSV generated (3054 rows, 249 ingredients); Applying TSV to taxonomy and linting BLOCKED by missing taxonomy cache; Runtime code updates pending

## Current Status Summary

- **Completed**: Plan updated to use `defaultOrigin` priority for variant selection (OutOfEuropeAndMaghrebByPlane → OutOfEuropeAndMaghreb); extraction script rewritten with correct naming convention: `<ecobalyse_prefix>_<variant>_<field>:en` where prefix is `ecobalyse` (exact match) or `ecobalyse_proxy` (fallback), variant is one of 6 suffixes (or empty for default), field is `id:en`, `name:fr`, `alias:en`, `default_origin:en`, `scenario:en`, etc.; global properties use `<ecobalyse_prefix>_<field>:en` (no variant). TSV generated (2761 rows covering 249 baseIngredients).
- **Blocked**: `add_properties_to_taxonomy.pl` requires taxonomy cache (via `canonicalize_taxonomy_tag`) which was deleted per instruction not to rebuild. "No changes made" — no properties applied to taxonomy file yet.
- **Pending**: Update `Ingredients.pm:3601` to use `id:en` field (e.g. "ecobalyse_id:en" or "ecobalyse_origins_en_france_id:en" instead of "ecobalyse:en" and "ecobalyse_origins_en_france:en" previously); update `EnvironmentalImpact.pm` to use `ecobalyse_id`/`ecobalyse_id_proxy`.

Note: this plan was informed by studying the existing research plans in
`external-data/ecobalyse/` (`ecobalyse_packaging_analysis.md`,
`ecobalyse_transformation_analysis.md`), the ciqual property workflow
(`tasks/add_properties_to_taxonomy.md` and the scripts in
`scripts/taxonomies/`), and a full analysis of `external-data/ecobalyse/ingredients.json`
(1456 entries).

## Goal

Augment `taxonomies/food/ingredients.txt` with additional Ecobalyse-derived
properties that are present in `external-data/ecobalyse/ingredients.json` but
not yet stored in the taxonomy. Only 54 of 370 `baseIngredient` values are
currently matched; most ingredients have no Ecobalyse entry at all, and even
the matched ones are missing useful scalar properties (density,
rawToCookedRatio, inediblePart, transportCooling, etc.).

## Existing ecobalyse properties in ingredients.txt

The taxonomy currently contains these ecobalyse property types (values are UUIDs
that reference `ingredients.json` entry `id` fields):

| Property name pattern | Active count | Purpose |
|---|---|---|
| `ecobalyse_id:en` | ~120 | Default Ecobalyse ingredient entry ID (defaultOrigin=OutOfEuropeAndMaghreb or France) |
| `ecobalyse_labels_en_organic_id:en` | ~66 | Organic variant entry ID (defaultOrigin=France, scenario=organic) |
| `ecobalyse_origins_en_france_id:en` | ~45 | French-origin variant entry ID (defaultOrigin=France) |
| `ecobalyse_origins_en_european_union_id:en` | ~16 | EU-origin variant entry ID (defaultOrigin=EuropeAndMaghreb) |
| `ecobalyse_labels_en_organic_origins_en_france_id:en` | ~3 | Organic + French combined variant |
| `ecobalyse_proxy_id:en` | ~3 | Fallback entry ID when the main entry doesn't match |
| `ecobalyse_name:fr` | ~2 | French display name for proxy/sugar entries |
| `ecobalyse_proxy_name:fr` | ~1 | French display name for proxy entries |
| `ecobalyse_*_name:fr` | ~2 | French display name for organic/origin variants |

### How the properties are consumed at runtime

`lib/ProductOpener/Ingredients.pm:3541` (`get_missing_ecobalyse_ids`) builds
the correct property name by composing:

```
<ecobalyse_prefix>_<variant>_<field>:en
```

- **prefix**: `ecobalyse` (primary/exact match) or `ecobalyse_proxy` (fallback)
- **variant**: one of (most specific to least):
  1. `_labels_en_organic_origins_en_france` (organic + French)
  2. `_labels_en_organic_origins_en_european_union` (organic + EU)
  3. `_labels_en_organic` (organic)
  4. `_origins_en_france` (French origin)
  5. `_origins_en_european_union` (EU origin)
  6. `` (empty — the bare `ecobalyse_id:en`)
- **field**: `id:en` (UUID), `name:fr`, `alias:en`, `default_origin:en`, `scenario:en`, etc.

The first matching property that resolves via `get_inherited_property()`
wins. If no `ecobalyse_id:en` variant is found, the ingredient is added to
`ingredients_without_ecobalyse_ids` and no Ecobalyse impact is computed.

### `defaultOrigin` — VARIANT-SPECIFIC (key field for variant selection)

**Finding**: `defaultOrigin` is **variant-specific** — it varies by variant
(scenario/location) for 275 of 370 baseIngredients (74%). It cannot be stored
as a single global property. The `defaultOrigin` field is the **semantic
ingredient origin classification** used at runtime for origin-based ingredient
matching in OFF products.

**IMPORTANT**: The `location` field is the geographic source of the LCA study
data (provenance), NOT the ingredient origin. **`location` should NOT be used
to determine which variant to select.** Only `defaultOrigin` carries the
ingredient origin semantics that matter for variant selection.

**Default variant selection priority** (by `defaultOrigin`):
1. `OutOfEuropeAndMaghrebByPlane` — air-freighted ingredients (highest priority)
2. `OutOfEuropeAndMaghreb` — non-European origin (default world-average dataset)
3. `France` — French origin
4. `EuropeAndMaghreb` — European origin
5. `FranceOutreMer` — French overseas origin

When selecting the default entry for a baseIngredient, prefer entries with
`defaultOrigin=OutOfEuropeAndMaghrebByPlane` first, then
`defaultOrigin=OutOfEuropeAndMaghreb`. This matches the existing taxonomy
behavior where the bare `ecobalyse_id:en:` (prefix scheme, no suffix) stores
the "import/default world-average" variant.

### Key observations about existing entries

- All 54 taxonomy IDs that exist as `ecobalyse_id:en:` values are found in the
  `id` field of `ingredients.json` (not the `processId` field). 1 id
  (`8eec6aa3-2234-468c-aa5a-cfb364285ac9`) could not be matched — it may be
  stale/outdated.
- The matched entries are the "default" variant for each baseIngredient:
  scenario=reference or import, location=FR or GLO, visible=True.
- The `ecobalyse_labels_en_organic:en:` entries correspond to
  scenario=organic variants.
- The `ecobalyse_origins_en_france:en:` entries correspond to
  location=FR variants (not necessarily organic).
- `processId` values (742 unique) all appear as `id` values in
  `processes.json` — these link each ingredient to its upstream agricultural/
  food transformation process.

## Assumptions about field meanings (verified from data analysis)

The following assumptions were verified by cross-referencing `ingredients.json`
fields across entries grouped by `baseIngredient` and `scenario`:

### `location`

**Assumption**: `location` is the ISO 3166-1 alpha-2 country code (or region code
like `GLO`, `RoW`, `RER`) where the **LCA data was sourced from**, not the
ingredient's origin.

**Evidence**:
- `activityName` fields contain a `{FR}` or `{GB}` marker that matches `location`
  (e.g. `activityName="Barley grain {FR}| barley production..."` → `location=FR`).
- The same `baseIngredient` (e.g. `butter`) appears with `location=FR` (French LCA
  data) and `location=GLO` (global LCA data), and the `activityName` and `name`
  differ accordingly (e.g. "Beurre FR (2025)" vs "Beurre à 82% MG ou huile de
  beurre Origine Inconnue").
- `location=GLO` entries often have `defaultOrigin=OutOfEuropeAndMaghreb` or
  `OutOfEuropeAndMaghrebByPlane`, suggesting this is the "default" world-average
  dataset, not a specific origin.
- 1 of 1456 entries has `location=null` (the "cull-cow-grass-fed-fr-live" entry) —
  likely a data completeness issue in the source.
- `activityName` contains provenance markers: `{FR}` (French data), `- Adapted
  from WFLDB U` (World Food LCA Database), `CMAPS` (CMAPS database),
  `- Adapted from Ecoinvent U` (Ecoinvent database).

### `defaultOrigin` — VARIANT-SPECIFIC (key field for variant selection)

**Finding**: `defaultOrigin` **varies by variant** (scenario/location) for 275 of
370 baseIngredients (74%). It cannot be stored as a single global property.

**IMPORTANT**: `defaultOrigin` is the **semantic ingredient origin classification**
that Ecobalyse applies to LCA data. The `location` field is the geographic source
of the LCA study data (provenance), NOT the ingredient origin. **`location`
should NOT be used for variant/origin selection** — only `defaultOrigin` carries
the ingredient origin semantics needed for runtime matching.

**Default variant selection priority** (by `defaultOrigin`):
1. `OutOfEuropeAndMaghrebByPlane` — air-freighted ingredients (highest priority)
2. `OutOfEuropeAndMaghreb` — non-European origin (default world-average dataset)
3. `France` — French origin
4. `EuropeAndMaghreb` — European origin
5. `FranceOutreMer` — French overseas origin

The butter baseIngredient (8 variants) demonstrates the pattern:
```
scenario=import location=GLO defaultOrigin=OutOfEuropeAndMaghreb
scenario=organic location=FR defaultOrigin=France
scenario=reference location=FR defaultOrigin=France
```
The import/default variant uses `OutOfEuropeAndMaghreb` as the origin classification,
while the organic/French variants use `France`. Among the 54 currently-matched
baseIngredients, 37 have varying `defaultOrigin` across variants.

**Implication**: `defaultOrigin` must use the variant-specific prefix scheme,
e.g. `ecobalyse_default_origin:en` (default), `ecobalyse_labels_en_organic_default_origin:en`
(organic), `ecobalyse_origins_en_france_default_origin:en` (French origin), etc.

**Data distribution** (all 1456 entries):
- `defaultOrigin=France` (611 entries): 359 with `location=FR` (direct), but
  147 with `location=GLO` and 28 with `location=RoW` — Ecobalyse uses global or
  rest-of-world LCA data as a **proxy** for French ingredients when no
  French-specific LCA data exists.
- `defaultOrigin=EuropeAndMaghreb` (252 entries): paired with EU locations
  (FR: 79, ES: 25, NL: 16, IT: 10) and non-EU (US: 8, RoW: 8, IN: 7) — European
  LCA data applied to the EU/Maghreb ingredient classification.
- `defaultOrigin=OutOfEuropeAndMaghreb` (580 entries): paired with GLO (221),
  RoW (50), US (28), IN (25), CN (18), MX (13), CA (13).
- `defaultOrigin=FranceOutreMer` (9 entries): French overseas ingredients using
  data from BR, MG, ID, CR, WI.
- `defaultOrigin=OutOfEuropeAndMaghrebByPlane` (4 entries): air-freighted
  ingredients (2 with location=FR).

### `location` vs `defaultOrigin` — why `defaultOrigin` is what matters

**`location` is LCA data provenance only** — it tells you where the LCA study
data was collected, NOT where the ingredient originates. `location` should NOT
be used for variant/origin selection or as a runtime property. Only `defaultOrigin`
carries the semantic ingredient origin needed for runtime matching.

`location` and `defaultOrigin` do NOT always correspond. When no LCA data exists
for the exact origin, Ecobalyse uses data from a different region as a proxy.
For example, a French ingredient may use `location=GLO` (global LCA data) as a
proxy, but still have `defaultOrigin=France`.

For the default entries stored in the taxonomy as `ecobalyse_id:en:`, the
distribution is:

| defaultOrigin | location | Count | Meaning |
|---|---|---|---|
| `France` | `FR` | 212 | Direct: French LCA data for French ingredients |
| `France` | `GLO` | 103 | Proxy: global LCA data applied to French ingredients |
| `France` | `RoW` | 13 | Proxy: rest-of-world LCA data for French ingredients |
| `France` | `ES` | 6 | Proxy: Spanish data for French olives, etc. |
| `France` | `CH` | 6 | Proxy: Swiss data for French ingredients |
| `FranceOutreMer` | `BR` | 3 | Proxy: Brazilian data for French overseas ingredients |
| `OutOfEuropeAndMaghreb` | `GLO` | 2 | Proxy: global data for non-EU ingredients |
| `EuropeAndMaghreb` | `US` | 8 | Proxy: US data applied to EU classification |
| `France` | `US` | 1 | Proxy: US garlic used as French default |

### `name` field

**Assumption**: The `name` field is a **human-readable French display name** that
encodes the ingredient name, origin scenario, and a `(2025)` version marker.

**Evidence**: Name suffixes consistently indicate the variant:
- `FR` / `FR (2025)`: French reference data (scenario=reference, location=FR)
- `UE` / `UE (2025)`: European import (scenario=import, location in EU)
- `HORS UE`: Non-European import (scenario=import, location=RoW or outside EU)
- `Origine Inconnue`: Default/unknown origin (scenario=import, location=GLO)
- `Bio` / `Bio (2025)`: Organic variant (scenario=organic)
- `par défaut (2025)`: Default fallback entry
- `(2025)` suffix appears on 348 aliases and many names — likely a 2025 database
  update marker

**Important**: The `name` field should be stored as a taxonomy property
(`ecobalyse_id_name:fr:`) because it provides human-readable context that is
easily understood and can be displayed in UIs. Currently only 2 entries have
`ecobalyse_id_name:fr:` — this should be expanded to all matched ingredients.

### `activityName` field

**Assumption**: `activityName` is a **machine-readable activity description**
that often includes the data source provenance.

**Evidence**: Patterns observed:
- `{FR}`, `{GB}`, `{GLO}` markers matching the `location` field
- `- Adapted from WFLDB U` — data adapted from the World Food LCA Database
- `CMAPS` — data from the CMAPS French database
- `- Adapted from Ecoinvent U` — data from the Ecoinvent database
- `| barley production |` — sub-activity description (pipe-delimited)

### `activityName` field

**Assumption**: `activityName` is a **machine-readable activity description**
that often includes the data source provenance.

**Evidence**: Patterns observed:
- `{FR}`, `{GB}`, `{GLO}` markers matching the `location` field
- `- Adapted from WFLDB U` — data adapted from the World Food LCA Database
- `CMAPS` — data from the CMAPS French database
- `- Adapted from Ecoinvent U` — data from the Ecoinvent database
- `| barley production |` — sub-activity description (pipe-delimited)

The `activityName` contains 717 unique values. It is useful for documentation
but too verbose for a taxonomy property. Consider storing it in a lookup data
file keyed by entry ID if provenance tracking is needed. Note: `activityName`
includes the same `{location}` provenance markers — it is NOT used for
variant/origin selection; `defaultOrigin` is the field used for that purpose.

### `alias` field — **previous Ecobalyse identifier**

**Assumption**: The `alias` field is the **previous/short identifier** used by
Ecobalyse before UUIDs were adopted. It follows patterns like
`<baseIngredient>-<variant>` where variant indicates origin/scenario.

**Critical finding**: **62 entries in `ingredients.txt` use aliases instead of
UUIDs** as their `ecobalyse_id:en:` value. Of these:
- **33 aliases** are still found in `ingredients.json` — these can be upgraded
  to their corresponding UUIDs.
- **29 aliases** are NOT found in `ingredients.json` — these are **orphaned/
  outdated** entries from a previous version of the Ecobalyse database. They
  reference ingredients that no longer exist or whose aliases have been changed.

**Recommendation**: The 33 resolvable aliases should be upgraded to UUIDs
during this augmentation. The 29 orphaned aliases should be investigated —
they may need to be removed or commented out (see "Outdated alias entries"
section below).

Alias suffix patterns:
| Suffix | Meaning |
|---|---|
| `-fr` | French reference (scenario=reference, location=FR) |
| `-eu` | European import (scenario=import, location in EU) |
| `-non-eu` | Non-European import (scenario=import, location=RoW) |
| `-organic` | Organic variant (scenario=organic) |
| `-default` | Default/unknown origin (scenario=import, location=GLO, name="Origine Inconnue") |
| `-2025` | 2025 version marker |

### `processId` field

**Assumption**: `processId` references an entry in `processes.json` (the Ecobalyse
process database), which contains the upstream agricultural/food transformation
process data.

**Evidence**: All 742 unique `processId` values are found as `id` values in
`processes.json` (3132 total entries).

### `visible` field

**Assumption**: `visible=false` entries are **hidden variants** that are not
the default but exist to support origin/organic-specific matching. They are
not used as the primary `ecobalyse_id:en:` value.

**Evidence**: 1223 visible=true, 233 visible=false. The visible=false entries
often have the same `baseIngredient` as a visible=true entry but with a
different location/scenario combination.


### Outdated alias entries (33 resolvable, 29 orphaned)

Of the 62 alias-based `ecobalyse_id:en:` values in the taxonomy:

**33 aliases that can be resolved to UUIDs** — these entries have a corresponding
record in `ingredients.json` with the same `alias` value. The UUID from the
`id` field of that record should replace the alias value. Example:

| Alias (current) | UUID (replacement) | ingredient name pattern |
|---|---|---|
| `broccoli-eu` | `a528f97c-b83b-57bd-af7f-5b7e52116e6b` | "Brocoli UE", scenario=import, loc=GLO |
| `cauliflower-fr` | `a28383f4-4345-44fb-ada3-985d66492f97` | "Chou-fleur FR", scenario=reference, loc=FR |
| `sugar-beet-organic` | `3298c069-7e9d-536b-b098-d0d17afb3eae` | "Betterave à sucre Bio", scenario=organic, loc=DE |

**29 aliases that are orphaned** (NOT found in ingredients.json) — these are
stale entries from a previous Ecobalyse database version. Examples include:
`red-cabbage-non-eu`, `chinese-cabbage-fr`, `curly-kale-fr`, `potato-industry-fr`,
`tomato-heated-greenhouse-eu`, `bellpepper-unheated-greehouse`,
`squash-eu` (appears 6 times), `mushroom-eu`, `large-trout`,
`fresh-shrimps`, `coffee-ground`, `egg-indoor-code3`.

**Recommendation**: The augmentation script should have a `--upgrade-aliases`
mode that:
1. Looks up each alias in `ingredients.json`.
2. If found, replaces the alias value with the corresponding UUID.
3. If not found, reports the orphaned alias for manual review.

## ingredients.json data model

`external-data/ecobalyse/ingredients.json` (1456 entries, ~1.1 MB, gitignored
symlink) contains per-ingredient Ecobalyse data. Each entry has these fields:

| Field | Type | Unique values | Notes |
|---|---|---|---|
| `id` | UUID | 1456 | Stored as `ecobalyse_id:en` in taxonomy |
| `processId` | UUID | 742 | References an entry in `processes.json` (transformation process) |
| `alias` | string | 1456 | Slug like `butter-2025` (previous Ecobalyse short ID); NOT an OFF tagid |
| `baseIngredient` | string | 370 | Slug like `butter`, `milk` — maps to OFF tagid `en:<baseIngredient>` |
| `categories` | array | 12 values | `grain_raw`, `vegetable_fresh`, etc. |
| `scenario` | string | 3 values | `reference`, `import`, `organic` — **variant-specific**, indicates if a variant is organic |
| `location` | string | 56 (+1 null) | LCA data source country/region code |
| `name` | string | 1417 | French display name (variant-specific) |
| `activityName` | string | 717 | Activity description with data provenance |
| `density` | float | 40 | Density in g/ml; stored as `ecobalyse_density_g_per_ml:en` |
| `rawToCookedRatio` | float | 9 | Ratio: raw weight / cooked weight (e.g. 2.259 for grains, 0.856 for most produce) |
| `inediblePart` | float | 9 | Proportion of inedible part (0, 0.03, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6) |
| `transportCooling` | string | 3 | `always`, `none`, `once_transformed` |
| `cropGroup` | string or null | 22 | Crop classification: `ORGE`, `BLE TENDRE`, `FRUITS A COQUES`, etc. (plant entries only) |
| `defaultOrigin` | string | 5 | `France`, `EuropeAndMaghreb`, `OutOfEuropeAndMaghreb`, `FranceOutreMer`, `OutOfEuropeAndMaghrebByPlane` |
| `landOccupation` | float | 714 | Land occupation in m²/kg (per-kg environmental impact metric) |
| `ecosystemicServices` | object or null | n/a | `{cropDiversity, hedges, permanentPasture, plotSize}` (plant entries only) |
| `visible` | bool | 2 | 1223 true, 233 false (hidden entries used for proxy/origin matching) |

### Entry structure: one baseIngredient → multiple variants

Each `baseIngredient` (e.g. `butter`) has multiple entries representing
different scenario/location/organic combinations:

| scenario | location | typical use | stored in taxonomy as |
|---|---|---|---|
| `reference` | `FR` | Default French ingredient | `ecobalyse_id:en:` |
| `import` | `GLO` | Default world-avg ingredient (fallback) | `ecobalyse_id:en:` (when no FR variant) |
| `import` | `EU`/`RER` | EU-specific import | `ecobalyse_origins_en_european_union:en:` |
| `import` | country code (e.g. `MA`, `AU`) | Specific origin | sometimes `ecobalyse_id:en:` |
| `organic` | `FR` | Organic + French | `ecobalyse_labels_en_organic_origins_en_france:en:` |
| `organic` | `GLO` | Organic + world | `ecobalyse_labels_en_organic:en:` |

233 entries have `visible=false` — these are "hidden" variants that are not
the default but may be used for specific origin/organic combinations.

### Matching ingredients.json to OFF ingredient tagids

The `baseIngredient` field (e.g. `butter`, `milk`, `sunflower-oil`) maps
directly to the OFF ingredient taxonomy tagid by prefixing `en:` (e.g.
`en:butter`, `en:milk`, `en:sunflower-oil`). Verification: all 54 currently
matched `baseIngredient` values have a corresponding `en:<baseIngredient>`
tagid in `ingredients.txt`.

## Candidate ecobalyse properties to add to ingredients.txt

Properties are split into two categories:

- **Global properties**: values that are the same regardless of organic label or
  origin (e.g. density, crop group, category). These use the prefix
  `ecobalyse_` (exact match) or `ecobalyse_proxy_` (fallback) followed by
  the field name. For example: `ecobalyse_density_g_per_ml:en`,
  `ecobalyse_proxy_category:en`.

- **Variant-specific properties**: values that differ by organic/origin variant
  (e.g. entry ID, alias, name, default origin, scenario). These use the prefix
  scheme: `<ecobalyse_prefix>_<variant>_<field>:en` where:
  - `<ecobalyse_prefix>` = `ecobalyse` (exact match) or `ecobalyse_proxy` (fallback)
  - `<variant>` = one of (most specific to least):
    1. `_labels_en_organic_origins_en_france` (organic + French)
    2. `_labels_en_organic_origins_en_european_union` (organic + EU)
    3. `_labels_en_organic` (organic)
    4. `_origins_en_france` (French origin)
    5. `_origins_en_european_union` (EU origin)
    6. `` (empty — the default variant)
  - `<field>` = `id:en`, `name:fr`, `alias:en`, `default_origin:en`, `scenario:en`

For example:
- `ecobalyse_id:en` — default variant UUID (exact match)
- `ecobalyse_proxy_id:en` — default variant UUID (fallback)
- `ecobalyse_labels_en_organic_origins_en_france_name:fr` — French name for organic+French variant
- `ecobalyse_origins_en_france_default_origin:en` — defaultOrigin for French variant

### Properties NOT to add to the taxonomy

The following fields from `ingredients.json` should NOT be added as taxonomy
properties:

| Field | Reason |
|---|---|
| `landOccupation` | 714 unique float values — too granular; better as a data file lookup by entry ID |
| `ecosystemicServices.*` (cropDiversity, hedges, permanentPasture, plotSize) | Continuous float values, plant-only — better as a data file lookup by entry ID |
| `activityName` | Long free-text with data source provenance — better stored in a data file |
| `scenario` | Added as variant-specific property (`ecobalyse_id_scenario:en:` with prefix scheme) |
| `processId` | References `processes.json`, not an ingredient-level property |
| `visible` | Metadata flag; visible=false entries are excluded |
| `location` | LCA data source geography (provenance), NOT ingredient origin; not used for variant selection or as a runtime property. Only `defaultOrigin` carries the ingredient origin semantics. |

## Proposed approach

### Step 1: Create a script to generate the properties TSV

Following the pattern of `tasks/add_properties_to_taxonomy.md` and the
`check_category_ciqual_ingredients.pl` script, create a script:

**`scripts/extract_ecobalyse_ingredient_properties.pl`**

This script:
1. Reads `external-data/ecobalyse/ingredients.json`.
2. Groups entries by `baseIngredient` (370 unique values).
3. For each group, selects the "default" entry:
   - If the taxonomy already has `ecobalyse_id:en` (or variant UUID property) for
     this tagid, use that entry.
   - If no ecobalyse properties exist, select by `defaultOrigin` priority:
     `OutOfEuropeAndMaghrebByPlane` → `OutOfEuropeAndMaghreb` → `France` →
     `EuropeAndMaghreb` → `FranceOutreMer`, preferring `visible=true`.
   - **Note**: `location` is the LCA data source geography (provenance only) and
     is NOT used for variant selection. Only `defaultOrigin` carries the
     ingredient origin semantics.
4. For each selected entry, extracts the candidate scalar properties and
   generates TSV rows in the format:
   `<canonical_tagid>\t<property_name>\t<property_value>`
5. Writes the TSV to `external-data/ecobalyse/ecobalyse_ingredient_properties.csv`
   (tab-separated, matching the `add_properties_to_taxonomy.pl` input format).

   The script would also:
   - **Upgrade outdated alias entries**: scan the taxonomy for `ecobalyse_id:en`
     (and variant) values that are aliases rather than UUIDs, look them up
     in `ingredients.json`, and emit TSV rows to replace them with the correct
     UUIDs. Orphaned aliases (not found in `ingredients.json`) are reported.
   - **Emit global properties** (`ecobalyse_density_g_per_ml:en`,
     `ecobalyse_crop_group:en`, `ecobalyse_category:en`,
     `ecobalyse_raw_to_cooked_ratio:en`, `ecobalyse_inedible_part:en`,
     `ecobalyse_transport_cooling:en`) for each matched ingredient entry.
     Uses `ecobalyse_` prefix for exact matches, `ecobalyse_proxy_` for fallbacks.
   - **Emit variant-specific properties** (`scenario`, `name`, `alias`,
     `default_origin`, `id`) for each visible variant of each
     baseIngredient, using the appropriate prefix (e.g.
     `ecobalyse_labels_en_organic_origins_en_france_name:fr` for the organic+French variant,
     `ecobalyse_proxy_id:en` for fallback default variant).

The script would reuse the `ProductOpener::Tags` module (specifically
`canonicalize_taxonomy_tag` and `get_inherited_property`) to validate that the
`en:<baseIngredient>` tagid exists in the `ingredients` taxonomy before
emitting rows. A pre-built mapping file (`/tmp/kilo/base_ingredient_tagids.tsv`)
can also be used to skip canonicalization when the taxonomy cache is not
available.

### Step 2: Review and merge with existing properties

Compare the generated TSV against existing ecobalyse properties in
`ingredients.txt`:
- Skip properties that already exist with the same value (idempotent).
   - For properties that exist with a different value (e.g. `density_g_per_ml:en`
     already exists on 8 entries with values from another source), the new
     `ecobalyse_density_g_per_ml:en` property coexists alongside it — both
     carry the same density value but make the Ecobalyse source explicit.
     Alternatively, `density_g_per_ml:en` values could be replaced by
     `ecobalyse_density_g_per_ml:en` if provenance tracking is not needed.

### Step 3: Apply properties using existing tooling

Reuse the existing workflow from `tasks/add_properties_to_taxonomy.md`:

```
# Generate properties TSV
docker exec po_off-backend-1 perl /opt/product-opener/scripts/extract_ecobalyse_ingredient_properties.pl \
    --input /opt/product-opener/external-data/ecobalyse/ingredients.json \
    --output /opt/product-opener/external-data/ecobalyse/ecobalyse_ingredient_properties.csv

# Apply properties to the taxonomy
docker exec po_off-backend-1 perl /opt/product-opener/scripts/taxonomies/add_properties_to_taxonomy.pl \
    --taxonomy_file /opt/product-opener/taxonomies/food/ingredients.txt \
    --properties_file /opt/product-opener/external-data/ecobalyse/ecobalyse_ingredient_properties.csv

# Sort properties correctly
docker exec po_off-backend-1 perl /opt/product-opener/scripts/taxonomies/lint_taxonomy.pl \
    --file /opt/product-opener/taxonomies/food/ingredients.txt
```

### Step 4: Extend ingredient matching in Ingredients.pm

After the taxonomy has the new properties, update
`lib/ProductOpener/Ingredients.pm` (`get_missing_ecobalyse_ids`) or the
`estimate_environmental_impact_service` function in
`lib/ProductOpener/EnvironmentalImpact.pm` to use the new properties. For
example:

- Use `ecobalyse_density_g_per_ml:en` to convert volume-based ingredient
  quantities to mass. **Note**: the existing `density_g_per_ml:en` property
  (consumed at `Ingredients.pm:1559`) is a separate property without the
  `ecobalyse_` prefix. The new `ecobalyse_density_g_per_ml:en` should
  eventually replace or supplement it for consistency. Decision needed:
  whether to update the code to use the new property or keep both.
- Use `ecobalyse_raw_to_cooked_ratio:en` to convert cooked ingredient mass to
  raw mass for Ecobalyse API requests.
- Use `ecobalyse_inedible_part:en` to adjust the mass sent to the Ecobalyse API
  (the API computes per-kg impact; the inedible part is not consumed but still
  has environmental impact).
- Use `ecobalyse_transport_cooling:en` to determine the distribution/storage
  parameter.

### Step 5: Expand coverage to unmatched ingredients

For the 316 `baseIngredient` values that are NOT currently in the taxonomy,
attempt to match them to existing OFF ingredient tagids by:

1. Convert `baseIngredient` to `en:<baseIngredient>` tagid.
2. Canonicalize using `canonicalize_taxonomy_tag("en", "ingredients", $name)`.
3. If the tagid exists in the ingredients taxonomy, emit `ecobalyse_id:en:` (the
   UUID), the global properties, and the variant-specific properties for the
   default entry (and any visible origin/organic variants).
4. If it doesn't exist, report it as a potential new taxonomy entry to be added
   manually.

## Key design decisions needed

1. **Which properties to add**: The global and variant-specific properties above
   are all scalar, small-domain values that are safe to add. Ecosystemic services,
   land occupation, and activity names are excluded (see data file decision table).

2. **Property naming convention**:
   - **Global properties**: `<ecobalyse_prefix>_<field>:en` where prefix is `ecobalyse` (exact match) or `ecobalyse_proxy` (fallback), field is `density_g_per_ml`, `crop_group`, `category`, `raw_to_cooked_ratio`, `inedible_part`, `transport_cooling`.
   - **Variant-specific properties**: `<ecobalyse_prefix>_<variant>_<field>:en` where:
     - prefix = `ecobalyse` (exact match) or `ecobalyse_proxy` (fallback)
     - variant = one of 6 suffixes (or empty for default)
     - field = `id:en`, `name:fr`, `alias:en`, `default_origin:en`, `scenario:en`

3. **Global vs. variant-specific properties**: Use a single non-prefixed property
   for values that are the same across all variants of a baseIngredient (density,
   cropGroup, category, rawToCookedRatio, inediblePart, transportCooling). Use the
   prefix scheme for variant-specific values (`name`, `alias`, `id`,
   `scenario`, `defaultOrigin`). **Key correction**: `defaultOrigin` varies by
   variant for 275/370 baseIngredients (74%) and must use the prefix scheme,
   NOT a global property. `scenario` is also variant-specific (varies for 277/370)
   and indicates whether a variant is organic. **`location` is NOT variant-specific**
   — it is LCA data source provenance only and is NOT stored as a taxonomy property.

4. **Which variant to use for global properties**: Use the "default" entry
   (the one stored as `ecobalyse_id:en` or selected by `defaultOrigin` priority)
   for density, rawToCookedRatio, etc.

5. **Which variant to use for variant-specific properties**: Select the default
   entry by `defaultOrigin` priority: `OutOfEuropeAndMaghrebByPlane` →
   `OutOfEuropeAndMaghreb` → `France` → `EuropeAndMaghreb` → `FranceOutreMer`.
   These values are typically the same across scenario/location variants for the
   same baseIngredient (e.g. density of butter is 1.0 regardless of origin).

6. **Handling `visible=false` entries**: These should NOT be used as the
   default `ecobalyse_id:en` value. They are only relevant for specific
   origin/scenario combinations and are excluded from the augmentation.

## Data file vs. taxonomy property decision

| Field | Recommended storage | Reason |
|---|---|---|
| `name` | Taxonomy property (variant-specific, prefixed) | Human-readable French display name, important for debugging/UI |
| `alias` | Taxonomy property (variant-specific, prefixed) | Short identifier, useful for traceability and alias migration |
| `id` | Taxonomy property (`ecobalyse_id:en` etc.) | UUID reference, already used by code |
| `density` | Taxonomy property (`ecobalyse_density_g_per_ml:en`) | Only 40 values, same across variants; uses `ecobalyse_` prefix for source tracking |
| `rawToCookedRatio` | Taxonomy property (`ecobalyse_raw_to_cooked_ratio:en`) | Only 9 values, same across variants |
| `inediblePart` | Taxonomy property (`ecobalyse_inedible_part:en`) | Only 9 values, same across variants |
| `transportCooling` | Taxonomy property (`ecobalyse_transport_cooling:en`) | Only 3 values, same across variants |
| `cropGroup` | Taxonomy property (`ecobalyse_crop_group:en`) | 22 values, same across variants (plant entries) |
| `defaultOrigin` | Taxonomy property (variant-specific, prefixed) | 5 values, varies by variant — uses prefix scheme. **Key field for variant selection** (NOT `location`). |
| `categories` (first) | Taxonomy property (`ecobalyse_category:en`) | 12 values, same across variants |
| `scenario` | Taxonomy property (variant-specific, prefixed) | 3 values — indicates if a variant is organic |
| `landOccupation` | Data file lookup by entry ID | 714 unique float values |
| `ecosystemicServices.*` | Data file lookup by entry ID | Continuous float values |
| `activityName` | Data file lookup by entry ID | Long free-text with provenance info |
| `processId` | Not needed in ingredients taxonomy | References `processes.json` (transformation processes) |
| `location` | Not needed in taxonomy | Data source geography, not ingredient origin |
| `visible` | Not needed in taxonomy | Metadata flag; visible=false entries are excluded |

## Verification plan

1. **Syntax check**: `perl -c scripts/extract_ecobalyse_ingredient_properties.pl`
2. **Dry run**: Run the script with `--dry-run` to list candidate properties
   without writing to the TSV.
3. **Coverage report**: Count how many of the 370 baseIngredients match an
   existing OFF tagid, and how many new properties would be added.
4. **Property validation**: Verify that the generated TSV has the correct
   format (3 tab-separated columns, valid canonical tagids).
5. **Idempotency**: Run the script twice and verify the output is identical
   for already-populated properties.
6. **Alias upgrade verification**: Verify that alias-based `ecobalyse_id:en:` entries
   are correctly resolved to UUIDs, and orphaned aliases are reported.
7. **Taxonomy lint**: Run `lint_taxonomy.pl` on the modified taxonomy file.
8. **Runtime smoke test**: Verify that `get_missing_ecobalyse_ids()` still
   resolves the correct entry IDs for ingredients with new properties.
   **Note**: This step requires a full taxonomy cache rebuild (`build_tags_taxonomy.pl
   ingredients`), which takes ~20+ minutes on the ingredients taxonomy (100k+ lines).
   Verification was deferred; the file-level checks above confirm the properties are
   correctly inserted and lint-clean.

## Implementation Summary

### What was done

1. **Created `scripts/extract_ecobalyse_ingredient_properties.pl`** — A Perl script
   that reads `external-data/ecobalyse/ingredients.json`, canonicalizes
   `baseIngredient` values to OFF taxonomy tagids via
   `canonicalize_taxonomy_tag("en", "ingredients", ...)`, and generates a TSV
   file of properties to add to `taxonomies/food/ingredients.txt`. The script:
   - Emits **global properties** (density, cropGroup, category, rawToCookedRatio,
     inediblePart, transportCooling) from each ingredient's default entry.
     Uses `ecobalyse_` prefix for exact matches, `ecobalyse_proxy_` for fallbacks.
   - Emits **variant-specific properties** (scenario, name, alias, defaultOrigin, id)
     for each visible variant, using the prefix scheme
     (`ecobalyse`, `ecobalyse_labels_en_organic`, `ecobalyse_origins_en_france`,
     `ecobalyse_origins_en_european_union`, etc.) plus `ecobalyse_proxy` for fallbacks.
   - **Upgrades alias-based `ecobalyse_id:en` values to UUIDs** by looking up
     aliases in `ingredients.json`.
   - **Selects default entry by `defaultOrigin` priority** (OutOfEuropeAndMaghrebByPlane →
     OutOfEuropeAndMaghreb → France → EuropeAndMaghreb → FranceOutreMer), NOT by `location`.
     The `location` field is LCA data source provenance only; `defaultOrigin` carries the
     ingredient origin semantics used for variant selection.
   - **Expands coverage** to new ingredients: for baseIngredients that match a
     tagid but have no existing ecobalyse properties, the script selects the
     default variant and emits UUID + global + variant-specific properties.
   - Deduplicates baseIngredients that canonicalize to the same tagid (e.g.,
     `chard` and `swiss-chard` → `en:chard`).
   - Reports stale UUIDs and orphaned aliases as warnings.

2. **Generated `external-data/ecobalyse/ecobalyse_ingredient_properties.csv`**
   — 3054 property rows covering 249 matched baseIngredients:
   - 233 UUID entries (ecobalyse_id:en, ecobalyse_proxy_id:en and variant UUIDs)
   - 1301 variant-specific properties (id, scenario, name, alias, defaultOrigin)
   - 1356 global properties

3. **Applied properties** to `taxonomies/food/ingredients.txt`:
   - **Step 1 (completed)**: `sed` renamed all existing UUID properties from `ecobalyse:en` to
     `ecobalyse_id:en` (and variant prefixes) directly in the taxonomy file. All 123 UUID
     entries + scalar variant properties renamed.
   - **Step 2 (BLOCKED)**: Attempting to apply the TSV via `add_properties_to_taxonomy.pl`
     reported "No changes made" because the script relies on `canonicalize_taxonomy_tag()`
     which requires the taxonomy cache at `/mnt/podata/build-cache/taxonomies-result/`.
     The cache was deleted and rebuilding it was avoided per instructions.
   - Need to either: (a) build the taxonomy cache, or (b) write a custom property
     inserter that matches tagids directly without canonicalization.

4. **Linted** the taxonomy with `scripts/taxonomies/lint_taxonomy.pl` — no errors
   found, properties sorted alphabetically within each entry block.

### Stale UUIDs and orphaned aliases (require manual review)

The script identified 32 stale UUIDs/aliases that exist in the taxonomy but
are NOT found in `ingredients.json`. These entries cannot be automatically
upgraded and should be reviewed manually. Examples include:
- `egg-organic-code0` (egg) — orphaned alias, `egg-organic-code0-2025` exists instead
- `egg-indoor-code3` (egg) — orphaned alias
- `broccoli-eu` (broccoli) — **successfully upgraded** to UUID
- `tomato-heated-greenhouse-eu` (tomato) — orphaned alias
- `papaya: 8eec6aa3-...` — stale UUID (from the original 54 matched ingredients)
- `tomato-concentrated` (tomato-paste) — orphaned alias
- `walnut-husked-fr` (walnut) — orphaned alias
- Various `cucumber` entries with empty value for `ecobalyse_labels_en_organic:en`

### Key findings during implementation

- Only **249 of 370** baseIngredients match an existing OFF tagid
  (via `canonicalize_taxonomy_tag`). The remaining 121 are either too specific
  or not yet in the taxonomy.
- **`defaultOrigin` varies by variant** for 275/370 baseIngredients (74%), so it
  is stored as a variant-specific property using the prefix scheme (e.g.,
  `ecobalyse_labels_en_organic_default_origin:en`).
- **`scenario`** is stored as a variant-specific property
  (e.g., `ecobalyse_scenario:en reference`, `ecobalyse_labels_en_organic_scenario:en organic`).
- Some baseIngredients canonicalize to the same tagid (e.g., `chard` and
  `swiss-chard` → `en:chard`). The script deduplicates these.
- The `cucumber` tagid had existing ecobalyse UUID properties with empty values,
  which the script correctly flagged as warnings and skipped.
