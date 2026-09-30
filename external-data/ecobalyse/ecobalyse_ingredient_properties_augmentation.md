# Plan: Ecobalyse Ingredient Properties Extraction

## Status: IMPLEMENTED

Extracts Ecobalyse ingredient properties for the OFF ingredients taxonomy from
`processes.json` (filtered to `food2` scope + `ingredient` category). Fully
data-driven — does NOT read existing ecobalyse properties from the taxonomy.
Uses `canonicalize_taxonomy_tag()` exclusively for tagid resolution.

## Data Source

`external-data/ecobalyse/processes.json` contains 1456 ingredient entries with
the same data as `ingredients.json`, but field locations differ:

| Field              | Old ingredients.json        | New processes.json                          |
|--------------------|-----------------------------|---------------------------------------------|
| `baseIngredient`   | top-level                   | `metadata.ingredient.baseIngredient`        |
| `scenario`         | top-level                   | `metadata.ingredient.scenario`              |
| `defaultOrigin`    | top-level                   | `metadata.defaultOrigin`                    |
| `cropGroup`        | top-level                   | `metadata.ingredient.cropGroup`             |
| `density`          | top-level                   | `metadata.ingredient.density`               |
| `inediblePart`     | top-level                   | `metadata.ingredient.inediblePart`          |
| `rawToCookedRatio` | top-level                   | `metadata.ingredient.rawToCookedRatio`      |
| `transportCooling` | top-level                   | Derived from `transported_cooled` in `categories` |
| `categories[0]`    | `grain_raw`, `vegetable_fresh`, etc. | `ingredient` (not useful for category) |

Filter criteria: `"food2"` in `scopes` AND `"ingredient"` in `categories` (all 1456 entries).

## defaultOrigin code mapping

| Code | Full name            | Proxy? |
|------|----------------------|--------|
| `None` | (rest of world)    | YES    |
| `FR`   | France             | NO     |
| `REM`  | Europe and Maghreb | NO     |
| `ROF`  | France d'outre-mer | NO     |

## Scripts

### 1. `scripts/match_base_ingredients_to_off.pl`

Resolves baseIngredient names from `base_ingredients.json` (370 names) to OFF
taxonomy tagids.

**Inputs** (hardcoded paths):
- `external-data/ecobalyse/base_ingredients.json` — 370 baseIngredient names (JSON string array)
- `external-data/ecobalyse/base_ingredients_to_off_ingredients_overrides.tsv` — optional manual overrides

**Output**:
- `external-data/ecobalyse/base_ingredients_to_off_ingredients.tsv`
  Format: `baseIngredient<TAB>tagid<TAB>source` (source = `taxonomy` or `override`)

**Flow**:
1. Initialize taxonomies (`init_taxonomies(0)`)
2. Load override file if it exists → `%overrides` (baseIngredient → tagid)
3. Load `base_ingredients.json` (JSON array of strings)
4. For each baseIngredient:
   - If in `%overrides`, record as `override` match
   - Else call `canonicalize_taxonomy_tag("en", "ingredients", $base_ingredient, \$exists)`
     - If `$exists` is true, record as `taxonomy` match with returned tagid
   - Else record as unmatched
5. Write all matched entries to output TSV
6. Print statistics to STDOUT
7. Exit 0 (even if some are missing)

### 2. `scripts/extract_ecobalyse_ingredient_properties.pl`

Generates ecobalyse properties TSV from `processes.json`.

**Inputs** (hardcoded paths):
- `external-data/ecobalyse/processes.json` (filtered: food2 scope + ingredient category)
- `external-data/ecobalyse/base_ingredients_to_off_ingredients.tsv` (from Script 1)
- `external-data/ecobalyse/base_ingredients_to_off_ingredients_overrides.tsv` (optional)

**Output**:
- `external-data/ecobalyse/ecobalyse_ingredient_properties_v2.csv`
  Format: `tagid<TAB>property_name<TAB>value`

## Property naming convention

### Global properties (always `ecobalyse_` prefix)

```
ecobalyse[_proxy]_density_g_per_ml:en
ecobalyse[_proxy]_crop_group:en
ecobalyse[_proxy]_raw_to_cooked_ratio:en
ecobalyse[_proxy]_inedible_part:en
ecobalyse[_proxy]_transport_cooling:en
ecobalyse[_proxy]_category:en
```

### Default variant (empty suffix)

```
ecobalyse_id:en           # if None+non-organic entry exists naturally
# OR
ecobalyse_proxy_id:en     # if no None+non-organic entry (fallback)
ecobalyse[_proxy]_scenario:en
ecobalyse[_proxy]_name:fr
ecobalyse[_proxy]_alias:en
ecobalyse[_proxy]_default_origin:en
```

### Variant-specific properties (for each non-default visible entry)

```
ecobalyse_<suffix>_id:en
ecobalyse_<suffix>_scenario:en
ecobalyse_<suffix>_name:fr
ecobalyse_<suffix>_alias:en
ecobalyse_<suffix>_default_origin:en
```

## Variant suffix mapping

### Scenario component
- `organic` → `_labels_en_organic`
- (any other / None / reference / import) → (empty)

### Origin component (defaultOrigin code)
- `FR` → `_origins_en_france`
- `REM` → `_origins_en_europe_and_maghreb`
- `ROF` → (empty — no origin suffix)
- `None` → (empty — no origin suffix)

### Full suffix = scenario_component + origin_component

## Key principle: "Origin none does not mean proxy"

The `ecobalyse_proxy_` prefix is used ONLY for the base fallback entry when no
None+non-organic entry exists naturally. All visible variants are emitted as
non-proxy properties.

## Default variant selection

Priority (when no natural None+non-organic entry exists): None (proxy) → ROF →
REM → FR (France last, since it's the most specific origin).

For the proxy fallback entry, values are copied from the best available entry
(non-organic preferred). Only the variant-specific properties (id, scenario, name,
alias, default_origin) use the proxy prefix. Global properties always use
`ecobalyse_` prefix.

## `defaultOrigin` vs `location`

**`location`** is the ISO 3166-1 alpha-2 country code where the LCA data was
sourced from (provenance). It is NOT the ingredient's origin and should NOT be
used for variant selection.

**`defaultOrigin`** is the semantic ingredient origin classification that
Ecobalyse applies to LCA data. It varies by variant for 275/370 baseIngredients
(74%) and is the key field for variant selection.

## Data file vs. taxonomy property decision

| Field             | Storage         | Reason                                    |
|-------------------|-----------------|-------------------------------------------|
| `name`            | Taxonomy property | French display name, useful for UI/debugging |
| `alias`           | Taxonomy property | Short identifier, useful for traceability |
| `id`              | Taxonomy property | UUID reference, already used by code      |
| `density`         | Taxonomy property | 40 values, same across variants           |
| `rawToCookedRatio`| Taxonomy property | 9 values, same across variants            |
| `inediblePart`    | Taxonomy property | 9 values, same across variants            |
| `transportCooling`| Taxonomy property | 3 values, same across variants            |
| `cropGroup`       | Taxonomy property | 22 values, same across variants (plant only) |
| `defaultOrigin`   | Taxonomy property | 5 values, varies by variant — key field    |
| `categories[0]`   | Taxonomy property | 12 values, same across variants           |
| `scenario`        | Taxonomy property | 3 values — indicates organic               |
| `landOccupation`  | Data file         | 714 unique float values                   |
| `ecosystemicServices.*` | Data file | Continuous float values                    |
| `activityName`    | Data file         | Long free-text with provenance info        |
| `processId`       | Not needed        | References `processes.json`                |
| `location`        | Not stored        | Data source geography, not ingredient origin |
| `visible`         | Not stored        | Metadata flag; visible=false excluded      |

## Execution sequence

```
1. Run match_base_ingredients_to_off.pl
   → generates base_ingredients_to_off_ingredients.tsv (+ stats on STDOUT)

2. (Manual step: review missing entries, edit overrides file if needed)

3. Run extract_ecobalyse_ingredient_properties.pl
   → generates ecobalyse_ingredient_properties_v2.csv
```

## Old-style (non-UUID) ecobalyse IDs in the taxonomy

The taxonomy previously contained non-UUID alias values in `ecobalyse_id:en` and
variant `_id` properties. Of 110 unique non-UUID values:

| Resolution path | Count | Description                          |
|-----------------|-------|--------------------------------------|
| Exact alias match | 68    | Found verbatim in ingredients.json   |
| `-2025` suffix  | 33    | Old alias + "-2025" resolves         |
| Truly orphaned  | 9     | Not resolvable                      |

The v2 extraction script does NOT upgrade existing alias-based IDs in the
taxonomy (it is fully data-driven and does not read existing properties). After
applying the new TSV, the taxonomy will have a mix of old (non-UUID) and new
(UUID) ecobalyse properties. To clean up old values:

1. Run `scripts/taxonomies/remove_properties_from_taxonomy.pl` with prefix
   `ecobalyse_` to remove ALL existing ecobalyse properties.
2. Run `scripts/taxonomies/add_properties_to_taxonomy.pl` to apply the freshly
   generated TSV.

This gives a clean slate — all properties will use UUIDs from `processes.json`.

## Unmatched ingredients (coverage gap)

Of 370 baseIngredients, 249 match an existing OFF tagid (with 2 merges:
chard+swiss-chard → en:chard, bean+lentils → en:beans). The remaining 121
have no corresponding tagid. 4862 total property rows are generated.

Recommendations for improving match rate:
1. Tagid canonicalization: some baseIngredients differ from the tagid directly.
2. Pluralization handling: try singular/plural variants.
3. Manual add: add new tagid entries for remaining unmatched ingredients.

## Verification plan

1. **Syntax check**: `perl -c scripts/extract_ecobalyse_ingredient_properties.pl`
2. **Run extraction**: Execute the two scripts in sequence, check STDOUT stats.
3. **Coverage report**: Verify 249 tagids resolved, 121 unmatched reported.
4. **Property validation**: Verify TSV has 3 tab-separated columns with valid tagids.
5. **Taxonomy cleanup**: Remove old properties, apply new TSV, lint.
6. **Taxonomy lint**: Run `lint_taxonomy.pl` on the modified taxonomy file.
7. **Runtime smoke test**: Verify `get_missing_ecobalyse_ids()` resolves correct
   entry IDs. Requires taxonomy cache rebuild (`build_tags_taxonomy.pl ingredients`).
