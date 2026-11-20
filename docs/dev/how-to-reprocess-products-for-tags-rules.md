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
required category must be reprocessed too, so that the tags it no longer adds are removed).

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
   - Products are only saved (with a new revision) when something changed. The `rules` source keeps its
     `last_updated_t` when the rules give the same result.

   For a very large category, `--query-codes-from-file` with the codes of `products.tsv` from the dry run limits the
   run to the products that change. It does not remove tags that a deleted or weakened rule no longer adds.

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
