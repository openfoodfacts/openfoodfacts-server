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

### 1. `external-data/ecobalyse/match_ecobalyse_base_ingredients_to_off.pl`

Resolves baseIngredient names from `base_ingredients.json` (370 names) to OFF
taxonomy tagids, and generates proxies for baseIngredients with transforming qualifiers.

**Inputs** (hardcoded paths):
- `external-data/ecobalyse/base_ingredients.json` — 370 baseIngredient names (JSON string array)
- `external-data/ecobalyse/base_ingredients_to_off_ingredients_overrides.tsv` — optional manual overrides
- `external-data/ecobalyse/base_ingredients_proxies_for_off_ingredients.tsv` — manual proxies
  (read to avoid adding an auto proxy to an OFF tagid that already has a manual proxy)

**Outputs**:
- `external-data/ecobalyse/base_ingredients_to_off_ingredients.tsv`
  Format: `baseIngredient<TAB>tagid<TAB>source`
  (source = `taxonomy`, `reordered`, `qualifiers`, `cheese` or `override`)
- `external-data/ecobalyse/base_ingredients_auto_proxies.tsv`
  Format: `target_tagid<TAB>source_baseIngredient`
- `external-data/ecobalyse/base_ingredients_to_off_ingredients_missing.tsv`

**Flow**, for each baseIngredient:
1. If in the overrides file → `override` match
2. Else `canonicalize_taxonomy_tag("en", "ingredients", $base)` → `taxonomy` match
3. Else move the last word to the front (e.g. `herb-fresh` → `fresh-herb`) → `reordered` match
4. Remove qualifiers from the name:
   - **Neutral qualifiers** (`fresh`, `raw`, `whole`, `shelled`, `husked`, `dehusked`, `cut`,
     `uncooked`, `aop`, `with-skin`) do not change the ingredient: if there is no direct match,
     the OFF tagid without the qualifiers is a `qualifiers` match (e.g. `dill-fresh` → `en:dill`,
     `pea-shelled-raw` → `en:pea`).
   - **Transforming qualifiers** (`dried`, `dehydrated`, `frozen`, `refined`, `cooked`, `canned`,
     `drained`) change the ingredient: the baseIngredient becomes an auto proxy for the OFF tagid
     without the qualifiers (e.g. `onion-dried` → `en:onion`, `refined-peanut-oil` → `en:peanut-oil`),
     even if the baseIngredient matched directly.
   - `in-shell` is not a neutral qualifier (the shell is an inedible part that changes the mass),
     and `sprouted` is not a transforming qualifier (sprouts are a different food, see the
     `mung-bean-sprouted` override).
5. `-cheese` suffix: `beaufort-cheese` → `en:beaufort` (`cheese` match), only if the OFF tagid
   is a cheese (e.g. not `goat-cheese` → `en:goat`).

After the loop, once all direct matches (`taxonomy`, `reordered`, `override`) are known:
- a `qualifiers` / `cheese` match is skipped if the OFF tagid already has a direct match from
  another baseIngredient (e.g. `comte-aop` and `comte-cheese` → `en:comte`): merging several
  baseIngredients in one OFF tagid would change its default entry.
- an auto proxy is skipped if the OFF tagid already has a match or a manual proxy
  (e.g. Ecobalyse has both `onion` and `onion-dried`: `en:onion` does not need a proxy),
  and an OFF tagid gets only one auto proxy.

### 2. `external-data/ecobalyse/extract_ecobalyse_ingredient_properties.pl`

Generates ecobalyse properties TSV from `processes.json`.

**Inputs** (hardcoded paths):
- `external-data/ecobalyse/processes.json` (filtered: food2 scope + ingredient category)
- `external-data/ecobalyse/base_ingredients_to_off_ingredients.tsv` (from Script 1)
- `external-data/ecobalyse/base_ingredients_to_off_ingredients_overrides.tsv` (optional)
- `external-data/ecobalyse/base_ingredients_proxies_for_off_ingredients.tsv` (manual proxies)
- `external-data/ecobalyse/base_ingredients_auto_proxies.tsv` (from Script 1)
- `external-data/ecobalyse/off_ingredients_without_ecobalyse_data.tsv` (manual list of OFF ingredients
  that must not inherit Ecobalyse data from their parents, see below)

**Options**:
- `--include-hidden-entries`: also use entries with `visible: false` (see below)

**Checks** (warnings, or an error for duplicates):
- mapped and proxy target tagids must exist in the ingredients taxonomy
- an OFF tagid gets only one proxy (manual proxies first, then auto proxies)
- no proxy on an OFF tagid that has its own Ecobalyse data
- the script dies if the output has more than one value for the same tagid + property

**Output**:
- `external-data/ecobalyse/ecobalyse_ingredient_properties.csv`
  Format: `tagid<TAB>property_name<TAB>value`

## Property naming convention

### Global properties

`ecobalyse_` prefix for matched baseIngredients, `ecobalyse_proxy_` prefix for
proxies (OFF ingredients using the data of another baseIngredient).

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
ecobalyse_id:en           # if None+non-organic entry exists naturally,
                          # or non-organic fallback (origin can be changed in Ecobalyse)
# OR
ecobalyse_proxy_id:en     # organic-only fallback, or proxy from another baseIngredient
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
- `ROF` → `_origins_en_france_overseas` (France d'outre-mer, `en:france-overseas` in the
  origins taxonomy; children include `en:guadeloupe`, `en:reunion-island`)
- `None` → (empty — no origin suffix)

### Full suffix = scenario_component + origin_component

## Key principle: "Origin none does not mean proxy"

All visible variants are emitted as non-proxy properties.

The `ecobalyse_proxy_` prefix is used only when the data is not the ingredient's
own non-organic data:
- organic-only fallback (see below): the organic label cannot be changed
- proxies: OFF ingredients that use the data of another baseIngredient
  (`base_ingredients_proxies_for_off_ingredients.tsv` and the auto-generated
  `base_ingredients_auto_proxies.tsv`)

Note: at runtime, `get_missing_ecobalyse_ids()` looks for `ecobalyse_*_id`
properties (including inherited ones from parents) before `ecobalyse_proxy_*_id`.
An ingredient's own `ecobalyse_proxy_id` is therefore shadowed if a parent has an
`ecobalyse_id`. This is why fallbacks that are the ingredient's own data must use
the `ecobalyse_` prefix.

## Hidden entries (`visible: false`)

Some Ecobalyse entries are hidden in the Ecobalyse UI (`visible: false`). The
Ecobalyse food API does not accept them: `/api/food/ingredients` only lists visible
ingredients, and `/api/food` returns a 400 error ("Ingrédient introuvable par id")
for a hidden ingredient id. Some baseIngredients only have hidden entries
(e.g. sardine, salmon, cod, shrimp, poultry, ground-beef): they get no properties,
and the corresponding OFF ingredients inherit the properties of their parents in
the taxonomy (e.g. en:sardine uses the en:fish proxy, en:minced-beef uses en:beef).

By default, hidden entries are ignored.

With `--include-hidden-entries`, hidden entries are used:
- the base default is selected among visible entries, or among hidden entries if
  there is no visible entry
- hidden variants are emitted when they don't collide with a visible variant
  (visible entries are preferred for the same variant suffix)
- hidden entries get a `ecobalyse[_proxy][_variant]_visibility:en: false` property
  (not emitted for visible entries)


## Inheritance and blocked ingredients

OFF ingredients without their own Ecobalyse properties inherit them from their parents
in the taxonomy (e.g. en:sardine uses the en:fish proxy, en:duck uses the en:poultry proxy).
A label or origin variant is only used if it comes from the taxonomy level of the base
match (`ecobalyse_id` or `ecobalyse_proxy_id`) or from a level below it, so that e.g.
organic rice flour uses the rice flour base match, and not the organic rice variant
of its en:rice parent.

Some OFF ingredients must not inherit the data of their parents: e.g. foie gras comes from
force-fed ducks and geese, with a much higher impact than the chicken breast proxy of
en:poultry. They are listed in `off_ingredients_without_ecobalyse_data.tsv`, and
`extract_ecobalyse_ingredient_properties.pl` emits `ecobalyse_id:en: undef` and
`ecobalyse_proxy_id:en: undef` for them: the `undef` value stops the inheritance from
the parents (for the ingredient and its children). As variants are only used with a base
match, blocking the base ids is enough. The script dies if a blocked ingredient has its
own Ecobalyse data.

## Default variant selection

Priority (when no natural None+non-organic entry exists): None → ROF →
REM → FR (France last, since it's the most specific origin).

For the fallback entry, values are copied from the best available entry
(non-organic preferred). If a non-organic entry exists, the fallback is the
ingredient's own entry with a different default origin: as the origin is a
parameter that can be changed in Ecobalyse (e.g. "Abricot Bio" has France as its
default origin, which can be changed to "---" for an unknown country), the
fallback is emitted with the `ecobalyse_` prefix. If only organic entries exist,
the fallback is emitted with the `ecobalyse_proxy_` prefix (only the
variant-specific properties: id, scenario, name, alias, default_origin). Global
properties use the `ecobalyse_` prefix.

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
| `visible`         | Taxonomy property | `ecobalyse[_variant]_visibility:en: false` only for hidden entries |

## Execution sequence

```
1. Run match_ecobalyse_base_ingredients_to_off.pl
   → generates base_ingredients_to_off_ingredients.tsv, base_ingredients_auto_proxies.tsv
     and base_ingredients_to_off_ingredients_missing.tsv (+ stats on STDOUT)

2. (Manual step: review missing entries, edit overrides file if needed)

3. Run extract_ecobalyse_ingredient_properties.pl
   → generates ecobalyse_ingredient_properties.csv
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

1. Run `scripts/taxonomies/remove_properties_from_taxonomy.sh` with prefix
   `ecobalyse_` to remove ALL existing ecobalyse properties.
2. Run `scripts/taxonomies/add_properties_to_taxonomy.pl` to apply the freshly
   generated TSV.

This gives a clean slate — all properties will use UUIDs from `processes.json`.

## Unmatched ingredients (coverage gap)

As of 2026-10-12: of 370 baseIngredients, 302 match an existing OFF tagid
(266 via taxonomy / reordering / qualifiers, 36 via overrides), and 7 more are
used as auto proxies. 63 are in the missing list. 6796 property rows are generated.

The extraction script reports "Unmatched baseIngredients (no OFF tagid)": the
baseIngredients in processes.json without an OFF tagid, and how many of them
are used as proxy sources (e.g. `fish-secondary-ingredient`).

## Verification plan

1. **Syntax check**: `perl -c external-data/ecobalyse/extract_ecobalyse_ingredient_properties.pl`
2. **Run extraction**: Execute the two scripts in sequence, check STDOUT stats.
3. **Coverage report**: Check the matched / missing counts and the warnings.
4. **Property validation**: Verify TSV has 3 tab-separated columns with valid tagids.
5. **Taxonomy cleanup**: Remove old properties, apply new TSV, lint.
6. **Taxonomy lint**: Run `lint_taxonomy.pl` on the modified taxonomy file.
7. **Runtime smoke test**: Verify `get_missing_ecobalyse_ids()` resolves correct
   entry IDs. Requires taxonomy cache rebuild (`build_tags_taxonomy.pl ingredients`).
