# Tags rules

Rules that add more precise tags to products from data that is already on the product:
categories, ingredients, labels, countries, brands, nutrients, names and ingredients lists.

Example: a product in `en:colas` that is not labelled, tagged or named caffeine-free gets `en:caffeinated-colas`.

The engine is `lib/ProductOpener/TagsRules.pm`. Design issue:
[#15342](https://github.com/openfoodfacts/openfoodfacts-server/issues/15342).

## Principles

- **Rules only add tags.** They never remove a tag entered by a contributor.
- **Rules must be close to 100% certain.** Each rules change comes with a dry-run report on the latest dump, and a
  manual review of a random sample that shows no false positive. Weaker signals add a **data quality warning**
  instead of a tag, so that the product is reviewed.
- **Rules are flat.** They see the tags from all the sources except the `rules` source. The output of a rule is never
  the input of another rule. If rule B needs the output of rule A, B repeats A's conditions.
- **Conflicts become warnings.** A rule never adds a category that is incompatible with a category the product already
  has. It adds the `en:category-rules-conflict` data quality warning instead. Incompatible categories come from the
  `exclusive:` groups of the rules files, and from the `incompatible_with:en` property of the categories taxonomy.
- Fix the taxonomies rather than listing variants in the rules: conditions on ingredients use `is_a`, so a rule
  should use a single generic ingredient.

## Files

`rules/<product type>/<target>/*.yml`, e.g. `rules/food/categories/beverages.yml`, `rules/food/data_quality/mustards.yml`.

A file is a mapping with a `rules:` list and an optional `exclusive:` list of groups of mutually exclusive categories:

```yaml
exclusive:
  - [en:caffeinated-colas, en:cola-sodas-without-caffeine]

rules:
  - id: colas-caffeinated                  # unique, lowercase letters, digits and dashes
    description: Colas are caffeinated unless ...
    if:                                    # all conditions must match
      categories: en:colas                 # required: the top-level categories condition
    unless:                                # the rule does not apply if any of the items matches
      - labels: en:no-caffeine
      - name: {any: 'caffeine.?free|decaf'}
    add:
      categories: en:caffeinated-colas     # must be a descendant of the required categories
    tests:                                 # run by tests/unit/tags_rules.t
      match:
        - categories: [en:colas]
      no_match:
        - categories: [en:colas]
          labels: [en:no-caffeine]
```

## Conditions

All the keys of a mapping must match (AND). A list of tags means "any of".

| Condition | Matches when |
| --- | --- |
| `categories: X` or `[X, Y]` | The product is in X or in a descendant of X. Same for `labels`, `countries`, `origins`, `states`. |
| `brands: xx:brand` | The product has the brand (case and accent insensitive). |
| `categories_exact: X` | X is one of the categories entered on the product (not a parent). |
| `ingredients: {contains: X}` | An ingredient, at any depth, is X or a child of X (`is_a`). |
| `ingredients: {first: X}` | The first ingredient is X or a child of X. |
| `ingredients: {in_first: {n: 3, of: X}}` | One of the first n ingredients is X or a child of X. |
| `ingredients: {percent: {of: X, min: 50, max: 100, use: declared}}` | The sum of the percents of the ingredients that are X (or a child of X) is in the range. `use`: `declared` (percent on the label), `estimate` (estimated percent) or `any` (declared, else estimate; the default). If a matching ingredient has no value, the condition does not match. |
| `ingredients: {count_of: {of: X, min: 2}}` | The number of distinct ingredients that are X (or a child of X) is in the range. |
| `ingredients: {known: true}` | The product has an ingredients list, and all its ingredients (at all depths) are in the taxonomy. |
| `nutrients: {cocoa: {min: 30, max: 64.9}}` | The value per 100 g or 100 ml as sold, from the aggregated nutrition set, is in the range. |
| `name: {fr: 'regexp', any: 'regexp'}` | A regular expression matches `product_name_<lc>` or `generic_name_<lc>` (and `product_name` / `generic_name` when `<lc>` is the main language). `any` applies to all languages. Case and accent insensitive. |
| `ingredients_text: {fr: 'regexp'}` | Same, on `ingredients_text_<lc>`. Last resort for things the parser does not keep. |
| `all: [conditions]` | All the conditions match. |
| `any: [conditions]` | At least one of the conditions matches. |
| `not: condition` | The condition does not match (`not: [c1, c2]`: none of them matches). |

## Actions

```yaml
add:
  categories: en:x                         # stored in tags_sources.categories.rules
  data_quality_warnings: en:y              # added by check_quality(), must exist in taxonomies/data_quality.txt
```

## Tests and dry run

- `make test-unit test=tags_rules.t` validates all the rules (tags exist in their taxonomies, `add` is under the
  required category, regular expressions compile, ids are unique, data quality tags exist) and runs the inline
  `match` / `no_match` fixtures. In fixtures, write tag and ingredient ids; the test adds the parents.
- `scripts/tags_rules_report.pl --jsonl openfoodfacts-products.jsonl.gz --output report.csv [--rules-ids a,b]`
  evaluates the rules on a dump (no MongoDB, no writes) and writes, per rule, the number of matches, of products
  already in the target, of products that would get the tag, of conflicts, and random samples to review.
