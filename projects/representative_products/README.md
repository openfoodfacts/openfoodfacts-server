# Representative products dataset

For each FoodEx2 term selected by the FOODTURE project (541 terms, see
`../foodture/foodture_foodex2_to_off_categories.csv`) and each country, the most scanned complete product
of the OFF category mapped to the term.

Countries: the 32 FOODTURE countries (EU27, Norway, Switzerland, UK, Serbia, Montenegro), plus Canada and
Iceland, which FOODTURE does not need (`foodture_country` = 0).

The set changes over time: contributors add products in stores for the categories that have none, and the
selection is run again.

## Files

- `selected_products.csv`: source of truth, one row per (country, FOODTURE code) that had a product.
  `status` is `active` or `removed` (with `date_removed` and the reason). The git history shows how the set evolved.
- `update_selected_products.py`: updates `selected_products.csv` from a new `representative_products.csv`,
  and writes `added_codes.txt` and `removed_codes.txt`.

## Marking the products in OFF: the `representative-products` team

The products of the set have the team `representative-products` in `teams_tags`. It can be queried in
MongoDB (`teams_tags=representative-products`) and browsed at https://world.openfoodfacts.org/team/representative-products

No human user must have this team in their profile: a team is added to every product that a member edits.
Contributors of the in-store campaign use another team, `representative-products-contributors`.

The first FOODTURE selection stays marked with `editors_tags=foodture`.

## Pipeline

All commands run on the production server, from the Product Opener directory
(scans are read from the `scans.json` files of the products).

```bash
# 1. ranking (categories are recomputed with the current taxonomy)
#    also ranks incomplete products that have photos (ingredients + nutrition photos selected, or 3+ photos)
./projects/foodture/select_representative_products.pl --jsonl openfoodfacts-products.jsonl.gz --years 2025,2026 \
  --output projects/foodture/ranked_products.csv \
  --incomplete-output projects/foodture/ranked_incomplete_products.csv

# 2. extraction with the FoodEx2 -> OFF mapping
#    missing_products.csv: country / category pairs without a complete product, with up to 3 incomplete
#    products that contributors could complete from their photos (for the in-store campaign)
./projects/foodture/extract_data_for_representative_products.pl --ranked-file projects/foodture/ranked_products.csv \
  --incomplete-ranked-file projects/foodture/ranked_incomplete_products.csv \
  --output projects/foodture/representative_products.csv --ingredients-output projects/foodture/ingredients_sum.csv \
  --missing-output projects/foodture/missing_products.csv

# 3. update the versioned list (then commit selected_products.csv)
python3 projects/representative_products/update_selected_products.py projects/foodture/representative_products.csv

# 4. add the team to the new products
./scripts/update_all_products.pl --query-codes-from-file projects/representative_products/added_codes.txt \
  --fields teams --user-id representative-products --team representative-products --force-new-version \
  --comment "representative products dataset: added"

# 5. remove the team from the products that left the set
./scripts/update_all_products.pl --query-codes-from-file projects/representative_products/removed_codes.txt \
  --remove-team representative-products --user-id representative-products \
  --comment "representative products dataset: removed"
```

Notes:
- `--fields teams` is needed in step 4: without a field or another action, `update_all_products.pl` stops with
  "Missing fields to update". With `--user-id` and `--force-new-version`, `store_product` runs and adds the
  `--team` of the user to `teams_tags`. The bot user also lands in `editors_tags`.
- In step 5, the query is the codes of the file *and* `teams_tags=representative-products`.
- `--query-codes-from-file` only keeps codes made of digits.
- Try each command with `--pretend` on a few codes first.
