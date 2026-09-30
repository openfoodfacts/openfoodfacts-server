# Plan: Ecobalyse Ingredient Properties Extraction (v2)

## Status: IMPLEMENTED

Two scripts created and tested:
- `scripts/match_base_ingredients_to_off.pl` — resolves 249/370 baseIngredients
- `scripts/extract_ecobalyse_ingredient_properties2.pl` — generates 4627 property rows

Both use hardcoded paths and `canonicalize_taxonomy_tag()` exclusively.

## Overview

Two scripts that extract ecobalyse properties for the OFF ingredients taxonomy
from Ecobalyse's `processes.json` and `base_ingredients.json`, using
`canonicalize_taxonomy_tag()` exclusively for tagid resolution. No existing
taxonomy ecobalyse properties are read — the scripts are fully data-driven and
idempotent.

## Important data source note: processes.json vs ingredients.json

`processes.json` (symlinked from `/home/stephane/ecobalyse/public/data/`) has the
same 1456 ingredient entries as `ingredients.json`, but field locations differ:

| Field | Old ingredients.json | New processes.json |
|---|---|---|
| `baseIngredient` | top-level | `metadata.ingredient.baseIngredient` |
| `scenario` | top-level | `metadata.ingredient.scenario` |
| `defaultOrigin` | top-level | `metadata.defaultOrigin` |
| `cropGroup` | top-level | `metadata.ingredient.cropGroup` |
| `density` | top-level | `metadata.ingredient.density` |
| `inediblePart` | top-level | `metadata.ingredient.inediblePart` |
| `rawToCookedRatio` | top-level | `metadata.ingredient.rawToCookedRatio` |
| `transportCooling` | top-level | Derived: `transported_cooled` in `categories` → `"always"` |
| `categories[0]` | `grain_raw`, `vegetable_fresh`, etc. | `ingredient` (not useful for category) |

### Filter criteria

Entries from `processes.json` are filtered to keep only those where:
- `"food2"` is in the `scopes` array (all 1456 filtered entries have this)
- `"ingredient"` is in the `categories` array (all 1456 filtered entries have this)

### defaultOrigin code mapping

The new `processes.json` uses compact Ecobalyse country codes:

| Code | Full name | Old conceptual name | Proxy? |
|---|---|---|---|
| `None` | (none — rest of world) | OutOfEurope | YES |
| `ROF` | France d'outre-mer | FranceOutreMer | NO |
| `REM` | Région - Europe et Maghreb | EuropeAndMaghreb | NO |
| `FR` | France | France | NO |

## Script 1: `scripts/match_base_ingredients_to_off.pl`

Resolves baseIngredient names from `base_ingredients.json` to OFF taxonomy tagids.

### Inputs (hardcoded paths at top of script)
- `external-data/ecobalyse/base_ingredients.json` — 370 baseIngredient names (JSON string array)
- `external-data/ecobalyse/base_ingredients_to_off_ingredients_overrides.tsv` — optional manual overrides

### Output
- `external-data/ecobalyse/base_ingredients_to_off_ingredients.tsv`
  Format: `baseIngredient<TAB>tagid<TAB>source`
  (source = `taxonomy` or `override`)

### Flow
1. Initialize taxonomies (`init_taxonomies(0)`)
2. Load override file if it exists → `%overrides` (baseIngredient → tagid)
3. Load `base_ingredients.json` (JSON array of strings)
4. For each baseIngredient:
   - If in `%overrides`, record as `override` match
   - Else call `canonicalize_taxonomy_tag("en", "ingredients", $base_ingredient, \$exists)`
     - If `$exists` is true, record as `taxonomy` match with returned tagid
   - Else record as unmatched
5. Write all matched entries to the output TSV
6. Print statistics to STDOUT:
   - Total baseIngredients: 370
   - Matched via taxonomy: N
   - Matched via overrides: M (separate count)
   - Missing (unmatched): P
   - List of missing baseIngredients
7. Exit 0 (even if some are missing)

## Script 2: `scripts/extract_ecobalyse_ingredient_properties2.pl`

Extracts ecobalyse properties for each baseIngredient from `processes.json`.

### Inputs (hardcoded paths at top of script)
- `external-data/ecobalyse/processes.json` (filtered: food2 scope + ingredient category)
- `external-data/ecobalyse/base_ingredients_to_off_ingredients.tsv` (from Script 1)
- `external-data/ecobalyse/base_ingredients_to_off_ingredients_overrides.tsv` (optional)

### Output
- `external-data/ecobalyse/ecobalyse_ingredient_properties_v2.csv`
  Format: `tagid<TAB>property_name<TAB>value`

### Flow
1. Load processes.json, filter: `"food2" in scopes` AND `"ingredient" in categories`
2. Load base_ingredients → tagid mapping (TSV from Script 1 + overrides)
3. Initialize taxonomies for `canonicalize_taxonomy_tag` fallback
4. Build `tagid -> [entries]` mapping (merge by tagid — multiple baseIngredients can canonicalize to the same tagid)
5. For each tagid:
   a. Filter to visible entries only
   b. Check if a None+non-organic entry exists (natural base default):
      - If YES: emit as `ecobalyse_id:en` (non-proxy, empty suffix) + global props
      - If NO: create fallback `ecobalyse_proxy_id:en` by copying from best entry (non-organic preferred, France-last) + global props
   c. For each OTHER visible entry (not the base default):
      - Emit as `ecobalyse_<variant_key>_id:en` (always non-proxy)
      - Skip if variant_key is empty (already emitted as base default)
      - Deduplicate by variant_key

### Key principle: "Origin none does not mean proxy"

The `ecobalyse_proxy_` prefix is used ONLY for the base fallback entry
(no label, no origin) when no None+non-organic entry exists naturally.

- All visible entry variants are emitted as `ecobalyse_<variant_key>_*` (non-proxy)
- If no None+non-organic entry exists, a fallback `ecobalyse_proxy_id:en` is created
  by copying values from the best available entry. Only the variant-specific
  properties (id, scenario, name, alias, default_origin) use the proxy prefix.
  Global properties (density, crop_group, etc.) always use `ecobalyse_` prefix.

### Variant suffix mapping

**Scenario component:**
- `organic` → `_labels_en_organic`
- (any other / None / reference / import) → (empty)

**Origin component (defaultOrigin code):**
- `FR` → `_origins_en_france`
- `REM` → `_origins_en_europe_and_maghreb` (CHANGED from `_origins_en_european_union`)
- `ROF` → (empty — no origin suffix, treated as bare variant)
- `None` → (empty — no origin suffix, treated as bare variant)

**Full suffix = scenario_component + origin_component**

### Property emission

#### Global properties (from default/proxy-default entry, always emitted)
```
ecobalyse[_proxy]_density_g_per_ml:en
ecobalyse[_proxy]_crop_group:en
ecobalyse[_proxy]_raw_to_cooked_ratio:en
ecobalyse[_proxy]_inedible_part:en
ecobalyse[_proxy]_transport_cooling:en
ecobalyse[_proxy]_category:en
```

#### Default variant (empty suffix, always emitted)
```
ecobalyse_id:en                        # if None+non-organic entry exists
# OR
ecobalyse_proxy_id:en                  # if no None+non-organic entry (fallback)
ecobalyse[_proxy]_scenario:en
ecobalyse[_proxy]_name:fr
ecobalyse[_proxy]_alias:en
ecobalyse[_proxy]_default_origin:en
```

#### Variant-specific properties (for each non-default visible entry, always non-proxy)
```
ecobalyse_<suffix>_id:en
ecobalyse_<suffix>_scenario:en
ecobalyse_<suffix>_name:fr
ecobalyse_<suffix>_alias:en
ecobalyse_<suffix>_default_origin:en
```

### Property naming example

For `en:broccoli` with 10 variants:
```
ecobalyse_origins_en_europe_and_maghreb_id:en      # REM variant
ecobalyse_origins_en_europe_and_maghreb_scenario:en
ecobalyse_origins_en_europe_and_maghreb_name:fr
ecobalyse_origins_en_europe_and_maghreb_alias:en
ecobalyse_origins_en_europe_and_maghreb_default_origin:en

ecobalyse_labels_en_organic_origins_en_europe_and_maghreb_id:en  # REM + organic
ecobalyse_labels_en_organic_origins_en_europe_and_maghreb_scenario:en
...

ecobalyse_origins_en_france_id:en      # FR variant
ecobalyse_labels_en_organic_origins_en_france_id:en  # FR + organic
...

ecobalyse_proxy_id:en                  # None (proxy) default
ecobalyse_proxy_scenario:en
ecobalyse_proxy_name:fr
ecobalyse_proxy_alias:en
ecobalyse_proxy_default_origin:en

ecobalyse_proxy_labels_en_organic_id:en  # None + organic (proxy)
ecobalyse_proxy_labels_en_organic_scenario:en
...

ecobalyse_id:en                          # FR default (if FR has highest priority among non-proxy)
```

## Execution sequence

```
1. Run match_base_ingredients_to_off.pl
   → generates base_ingredients_to_off_ingredients.tsv (+ stats on STDOUT)

2. (Manual step: review missing entries, edit overrides file if needed)

3. Run extract_ecobalyse_ingredient_properties2.pl
   → generates ecobalyse_ingredient_properties_v2.csv
```

## Note on runtime code

The runtime code in `lib/ProductOpener/Ingredients.pm:3836-3859` currently uses
`_origins_en_european_union` for EU/Maghreb origins. If we change the suffix to
`_origins_en_europe_and_maghreb`, the Ingredients.pm suffix loop must be updated
to match. This is tracked as a follow-up task.

## Expected results

Based on current data (tested 2026-09-30):
- 249 baseIngredients matchable via `canonicalize_taxonomy_tag`
- 121 unmatched (no corresponding tagid in the taxonomy)
- 247 tagids resolved (chard+swiss-chard share en:chard; bean+lentils share en:beans)
- 233 tagids with visible entries:
  - 182 with natural None+non-organic default (emitted as `ecobalyse_id:en`)
  - 51 with fallback proxy default (no None+non-organic entry → `ecobalyse_proxy_id:en`)
- 14 tagids with no visible entries (warnings)
- 4862 total property rows:
  - 1357 global properties (density, crop_group, raw_to_cooked_ratio, inedible_part, transport_cooling, category)
  - 3505 variant properties (id, scenario, name, alias, default_origin × variants)
