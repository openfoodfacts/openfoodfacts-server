# Explain tags rules

Tags rules add more precise tags to products from data that is already on the product: categories, ingredients,
labels, countries, nutrients, names and ingredients lists.

Example: a product in `en:colas` that is not labelled, tagged or named caffeine-free gets `en:caffeinated-colas`.

- Rules: `rules/<product type>/<target>/*.yml`, e.g. `rules/food/categories/beverages.yml`.
- Engine: `lib/ProductOpener/TagsRules.pm`.
- Tests: `tests/unit/tags_rules.t`.
- Dry run on a dump: `scripts/tags_rules_report.pl`, run with `make tags_rules_report` (see [Testing a rule](#testing-a-rule)).
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
  instead. Incompatible categories come from the `incompatible_with:en` property of the categories taxonomy (see
  below). Conflicts are also checked on the parents of the categories.
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

A file is a list of rules:

```yaml
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

### Rule compilation and errors

The first time a process needs the rules (e.g. to evaluate a product), the rules files of the product type are read,
and each rule is checked and compiled to Perl functions:

- tags and ingredients must exist in their taxonomies, with their canonical id;
- added categories must be children of the required categories;
- conditions must be known, and regular expressions must compile;
- rule ids must be unique, and each rule must have at least one `match` test product.

A rule with an error is skipped (the other rules still run) and the error is logged. `tests/unit/tags_rules.t`
fails on any error, so an invalid rule cannot be merged.

**When a taxonomy changes**, the rules are checked again: if a tag used in a rule is renamed (its canonical id
changes) or removed, `tags_rules.t` fails and gives the new canonical id. If a synonym is added (e.g. a new
translation of an ingredient), nothing needs to change in the rules: they use ids, and products get the new id.

### Incompatible categories

A rule never adds a category that is incompatible with another category of the product (or with a category added
by another rule): the category is not added and the product gets the `en:category-rules-conflict` data quality
warning instead. When 2 rules add incompatible categories, none of them is added.

Incompatible categories are set in the taxonomy, with the `incompatible_with:en` property (on one of the 2
categories), e.g. in `taxonomies/food/categories.txt`:

```text
en: Caffeinated colas
...
incompatible_with:en: categories:en:cola-sodas-without-caffeine
```

When a rule adds a category that cannot be combined with another one (e.g. caffeinated colas / colas without
caffeine), add the property in the same pull request. The property is also used by data quality checks: products
that have both categories get a `en:mutually-exclusive-tags-for-...` data quality error.

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
| `ingredients: {contains: X}` | An ingredient, at any depth, is X or a child of X (`is_a`). |
| `ingredients: {first: X}` | The first ingredient is X or a child of X. |
| `ingredients: {in_first: {n: 3, of: X}}` | One of the first n ingredients is X or a child of X. |
| `ingredients: {known: true}` | The product has an ingredients list, and all its ingredients (at all depths) are in the taxonomy. |
| `nutrients: {cocoa: {min: 30, max: 64.9}}` | The value per 100 g or 100 ml as sold, from the aggregated nutrition set, is in the range. |
| `name: {fr: 'regexp', any: 'regexp'}` | A regular expression matches `product_name_<lc>` or `generic_name_<lc>` (and `product_name` / `generic_name` when `<lc>` is the main language). `any` applies to all languages. Case and accent insensitive. One matching language is enough: with `{fr: 'complet', de: 'vollkorn'}`, a product whose French name matches is a match, whatever its German name. |
| `ingredients_text: {fr: 'regexp'}` | Same, on `ingredients_text_<lc>`. Last resort for things the parser does not keep. |
| `all: [conditions]` | All the conditions match. |
| `any: [conditions]` | At least one of the conditions matches. |
| `not: condition` | The condition does not match (`not: [c1, c2]`: none of them matches). |

Tags must be written with their canonical id (e.g. `en:colas`, not `en:cola`): the validation gives the canonical id
when it is not.

Other conditions (e.g. on brands, or on the percent of an ingredient) can be added to `TagsRules.pm` when a rule
needs them, with tests.

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
  make tags_rules_report dump=openfoodfacts-products.jsonl.gz rules=my-rule
  ```

  The script uses Product Opener's modules and taxonomies, so the target runs it in a one-off backend container
  (it needs the dev images and `make build_taxonomies`, not the running stack: no MongoDB, no writes). The dump is
  read from the host, and the files are written to `tmp/tags_rules_report/`: per rule, the number of matches, of
  products already in the target, of products that would get the tag, of conflicts (`report.csv`), random samples
  to review (`report_samples.csv`), and the changed products (`products.csv`).
- In the pull request, paste the report lines of the changed rules (matches, would add, conflicts), and say how many
  samples were reviewed and what was changed after the review.
