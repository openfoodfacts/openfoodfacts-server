# Explain tags rules

Tags rules add more precise tags to products from data that is already on the product: categories, ingredients,
labels, countries, brands, nutrients, names and ingredients lists.

Example: a product in `en:colas` that is not labelled, tagged or named caffeine-free gets `en:caffeinated-colas`.

- Rules: `rules/<product type>/<target>/*.yml`, e.g. `rules/food/categories/beverages.yml`.
- Engine: `lib/ProductOpener/TagsRules.pm`.
- Tests: `tests/unit/tags_rules.t`.
- Dry run on a dump: `scripts/tags_rules_report.pl`.
- Design issue: [#15342](https://github.com/openfoodfacts/openfoodfacts-server/issues/15342).

## Why rules?

Precise categories drive the Nutri-Score, the Green-Score, CIQUAL and Agribalyse matches, food groups and
comparisons. Many products only have a generic category (e.g. `en:colas`, `en:crispbreads`) while the rest of their
data (ingredients, labels, name) gives the precise one. Rules fill that gap, in a reviewable and testable way.

## Principles

- **Rules only add tags.** They never remove a tag entered by a contributor.
- **Rules must be close to 100% certain.** Each rules change comes with a dry-run report on the latest dump, and a
  manual review of a random sample that shows no false positive. Weaker signals add a **data quality warning**
  instead of a tag, so that the product is reviewed.
- **Rules refine a category the product already has.** Each rule has required categories, and can only add
  categories under them. A rule cannot add an unrelated category. This keeps rules safe (they only apply to products
  that a contributor already put in the required category), and the engine only evaluates the rules of the
  categories of the product. If a real need for unrelated categories appears, this can be relaxed later.
- **Rules are flat.** They see the tags from all the sources except the `rules` source. The output of a rule is never
  the input of another rule, so the order of the rules does not matter. If rule B needs the output of rule A, B
  repeats A's conditions.
- **Conflicts become warnings.** A rule never adds a category that is incompatible with a category the product already
  has, or with a category added by another rule. It adds the `en:category-rules-conflict` data quality warning
  instead. Incompatible categories come from the `exclusive:` groups of the rules files, and from the
  `incompatible_with:en` property of the categories taxonomy. Conflicts are also checked on the parents of the
  categories.
- **Fix the taxonomies rather than listing variants in the rules.** Conditions on tags and ingredients use `is_a`,
  so a rule should use a single generic ingredient (e.g. `en:wholemeal-flour`), and missing synonyms should be added
  to the taxonomy.

## Where the tags go

Tags added by rules are stored in the `rules` source of `tags_sources` (product schema 1004), with the rule ids
that added each tag:

```yaml
tags_sources:
  categories:
    rules:
      tags: [en:caffeinated-colas]
      last_updated_t: 1762800000
      rules: {en:caffeinated-colas: [colas-caffeinated]}
```

`categories_tags` is regenerated from all the sources. Rules run again on every product update, so the `rules`
source always reflects the current rules and data: if a contributor adds a "caffeine-free" label, the rule no longer
matches and the tag is removed from the `rules` source.

Products changed by a rule also get the misc tags `en:tags-added-by-rules` and `en:tags-rule-<rule id>`.

Data quality tags (`data_quality_warnings`, `data_quality_info`) are not stored: they are added by `check_quality()`.

## Flavor settings

`$options{tags_rules}` in `lib/ProductOpener/Config_<flavor>.pm` sets, for each flavor:

- `condition_tag_fields`: the tag fields that conditions can test (e.g. `labels: en:organic`);
- `add_tag_fields`: the tag fields that rules can add tags to (data quality tags can always be added).

Flavors without this setting do not run tags rules. Only Open Food Facts has it for now.

## Rules files

A file is a mapping with a `rules:` list and an optional `exclusive:` list:

```yaml
exclusive:
  - [en:caffeinated-colas, en:cola-sodas-without-caffeine]

rules:
  - id: colas-caffeinated
    description: Colas are caffeinated unless they are labelled, tagged or named caffeine-free
    comment: Free text for rule editors (optional)
    if:
      categories: en:colas
    unless:
      - labels: en:no-caffeine
      - categories: en:cola-sodas-without-caffeine
      - name: {any: 'caffeine.?free|decaf'}
    add:
      categories: en:caffeinated-colas
    tests:
      match:
        - categories: [en:colas]
      no_match:
        - categories: [en:colas]
          labels: [en:no-caffeine]
```

### Fields of a rule

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Unique id of the rule, in all the files of the product type: lowercase letters, digits and dashes. It is used in the misc tag `en:tags-rule-<id>` and in `tags_sources.<field>.rules.rules`, so it must not change when the rule is moved to another file (that is why ids are not prefixed with the file name). Duplicate ids make `tags_rules.t` fail. |
| `description` | yes | What the rule does, in one sentence. |
| `comment` | no | Notes for rule editors (e.g. why a case is excluded). Comments in the YAML (`#`) work too. |
| `if` | yes | The conditions that must all match. It must have a top-level `categories` condition: the **required categories**. The rule is only evaluated for products in one of those categories (or in a child). |
| `unless` | no | Cases where the rule must not apply, as a list (or a mapping): the rule does not apply if **any** of them matches. |
| `add` | yes | The tags to add, for each field. Added categories must be children of the required categories. |
| `tests` | yes | Test products: `match` (at least one) must match the rule, `no_match` must not. They are run by `tests/unit/tags_rules.t`. |

### Exclusive groups

`exclusive:` lists groups of categories that a product cannot have at the same time, e.g. a cola cannot be both
caffeinated and caffeine-free. If a rule would add a category of a group while the product already has another
category of the same group (or a child of it), the category is not added and the product gets the
`en:category-rules-conflict` data quality warning instead. The same applies when 2 rules would add categories of the
same group: none of them is added.

The `incompatible_with:en` property of the categories taxonomy works the same way, and is checked too.

## Conditions

### How conditions are combined

The YAML structure gives the logic, so that most rules need no `all` or `any`:

- Under `if` and `all`, the keys of a mapping, or the items of a list, must **all** match (AND).
- Under `any` and `unless`, **one** of the keys of the mapping, or one of the items of the list, must match (OR).
- Each item of a list is itself a condition whose keys must all match (AND).
- A list of tags in a tag condition means "any of": `categories: [en:x, en:y]`.
- `not: condition`: the condition does not match. `not: [c1, c2]`: none of them matches.

```yaml
if:
  categories: en:crispbreads                   # AND
  ingredients: {first: en:wholemeal-rye-flour} # AND
  any:                                         # AND (one of the following)
    - labels: en:organic
    - countries: en:sweden
unless:
  - labels: en:gluten-free                     # OR
  - name: {any: 'crackers?'}                   # OR
```

### List of conditions

| Condition | Matches when |
| --- | --- |
| `categories: X` or `[X, Y]` | The product is in X or in a child of X. Same for `labels`, `countries`, `origins`, `states`. |
| `brands: xx:brand` | The product has the brand (case and accent insensitive). |
| `categories_exact: X` | X is one of the categories entered on the product, not a parent of an entered category. Same for `labels_exact`, `countries_exact`, `origins_exact`, `states_exact`. |
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

Tags must be written with their canonical id (e.g. `en:colas`, not `en:cola`): the validation gives the canonical id
when it is not.

## Actions

```yaml
add:
  categories: en:x                         # stored in tags_sources.categories.rules
  data_quality_warnings: en:y              # added by check_quality(), must exist in taxonomies/data_quality.txt
```

## Testing a rule

- `make test-unit test=tags_rules.t` validates all the rules and runs their `match` / `no_match` test products.
  Validation errors give the file, the rule id and the path of the condition in the rule, e.g.
  `rules/food/categories/x.yml: rule my-rule: if.any[1].ingredients.first: tag 'en:xyz' does not exist in the
  ingredients taxonomy`.
- In test products, write tag and ingredient ids; the test adds the parents. Other fields (e.g. `product_name_fr`)
  are copied as is.
- Before merging, run the dry run on the latest dump and review the samples:

  ```bash
  ./scripts/tags_rules_report.pl --jsonl openfoodfacts-products.jsonl.gz --output report.csv --rules-ids my-rule
  ```

  It evaluates the rules on a dump (no MongoDB, no writes) and writes, per rule, the number of matches, of products
  already in the target, of products that would get the tag, of conflicts, and random samples to review.
