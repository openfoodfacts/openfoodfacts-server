# How to reprocess products after a tags rules change

Tags rules (`rules/<product type>/**/*.yml`, engine `lib/ProductOpener/TagsRules.pm`, design issue
[#15342](https://github.com/openfoodfacts/openfoodfacts-server/issues/15342)) are applied every time a product is
saved: the tags they add are stored in the `rules` source of `tags_sources` (e.g. `tags_sources.categories.rules`).

When rules are added or changed, existing products only get the new result on their next save. This runbook
reprocesses the impacted products right after a deploy, so that categories, Nutri-Score, Green-Score, CIQUAL codes,
food groups etc. are up to date.

## 1. Before merging a rules change: dry run

Run the dry run on the latest JSONL dump and attach the report to the PR:

```bash
./scripts/tags_rules_report.pl --jsonl openfoodfacts-products.jsonl.gz \
    --rules-ids colas-caffeinated,orange-sodas-without-juice \
    --output report.csv --products-output products.tsv
```

- `report.csv`: per rule, matches, products already in the target, products that would get a tag, conflicts, complete
  products and countries.
- `report_samples.csv`: 50 random products per rule. Review them by hand: **a rule must show no false positive**.
  Weaken the rule (or turn it into a data quality warning) otherwise.
- `products.tsv`: one line per product changed by a rule, with its code. It can be used with
  `--query-codes-from-file` below.

The dry run needs no MongoDB. To run it in the backend container, mount the directory of the dump, e.g.
`docker compose run --rm -v /path/to/dumps:/dumps:ro -v /tmp/out:/out backend perl scripts/tags_rules_report.pl --jsonl /dumps/openfoodfacts-products.jsonl.gz --output /out/report.csv`.

## 2. After the deploy: list the commands

Every rule has a required category (the top-level `categories:` of its `if:`). Only products in the required
categories can be changed by the rule. The report script prints one reprocessing command per required category:

```bash
./scripts/tags_rules_report.pl --print-reprocessing-commands [--rules-ids a,b] [--key tags_rules_20261201]
```

Example output for the first rules:

```bash
./scripts/update_all_products.pl --query categories_tags=en:biscuits --analyze-and-enrich-product-data --key tags_rules_20261201
./scripts/update_all_products.pl --query categories_tags=en:bouillon-cubes --analyze-and-enrich-product-data --key tags_rules_20261201
./scripts/update_all_products.pl --query categories_tags=en:colas --analyze-and-enrich-product-data --key tags_rules_20261201
...
```

Use `--rules-ids` to only print the categories of the rules that changed (when a rule is changed or deleted, its
required category must be reprocessed too, so that the tags it no longer adds are removed). `--rules-ids` reads the
current rules files: for a deleted rule, or a rule whose required category changed, take the old required category
from the git diff of the rule and add a command for it.

## 3. Count, then run

On the production server, as the `off` user, in `/srv/off`:

1. Count the products first (no processing):

   ```bash
   ./scripts/update_all_products.pl --query categories_tags=en:colas --count
   ```

2. Run the commands one at a time, in a `screen` / `tmux` session, and keep the logs:

   ```bash
   ./scripts/update_all_products.pl --query categories_tags=en:colas \
       --analyze-and-enrich-product-data --key tags_rules_20261201 2>&1 | tee tags_rules_20261201_colas.log
   ```

   - `--analyze-and-enrich-product-data` runs the full pipeline (`analyze_and_enrich_product_data()`), as on a
     product save. Rules change categories, so the categories properties, food groups and scores must be
     recomputed too: do not use a lighter option.
   - `--key` records the run in `update_key`, so an interrupted run can be resumed with the same command without
     reprocessing the products already done.
   - Every matched product is written (to the .sto file and MongoDB) with the new `update_key`. Only the products
     that changed get a new revision, a new `last_updated_t` and a push to the Redis stream. The `rules` source
     keeps its `last_updated_t` when the rules give the same result.

   **New rules: reprocess only the products the dry run changes.** No product has tags from a new rule yet, so
   there is nothing to remove, and `products.tsv` from the dry run lists the products to update. For the first rules,
   that is about 6,900 products instead of the 80,000 of their required categories (see [Volumes](#volumes)):

   ```bash
   ./scripts/update_all_products.pl --query-codes-from-file products.tsv \
       --analyze-and-enrich-product-data --key tags_rules_20261201 2>&1 | tee tags_rules_20261201.log
   ```

   Products edited after the date of the dump are not in the list: they get the rules on their next save.
   **Changed, weakened or deleted rules: reprocess the whole required categories** with the commands of step 2,
   because the codes list does not contain the products from which a rule must now remove a tag.

3. Do the same on the producers platform (`/srv/off-pro`): rules also run there. The `rules` source is not exported
   from the producers platform to the public platform; the public platform recomputes it.

## 4. Check

- `https://world.openfoodfacts.org/misc/en:tags-rule-<rule id>` lists the products changed by a rule (e.g.
  `en:tags-rule-colas-caffeinated`), and `misc/en:tags-added-by-rules` all products with tags added by rules.
- `https://world.openfoodfacts.org/data-quality-warning/en:category-rules-conflict` lists the products where a rule
  found a conflict with an existing category: they need a contributor review.
- The counts should be close to the "would add" and "conflicts" columns of the dry run report.

## Volumes

On the 2026-11-10 dump (4.9M products), the required categories of the first rules contain about 80,000 products in
total (the dry run reads 79,708 candidates), most of them in `en:biscuits` (~59,000) and `en:dark-chocolates`
(~12,000).
The rules change only 6,905 of them (6,843 get a tag, 62 get a conflict warning): `biscuits-wholemeal-wheat` alone
requires `en:biscuits` but adds 680 products. Hence the codes list for new rules in step 3.
