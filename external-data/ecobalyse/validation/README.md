# Ecobalyse environmental cost validation

`validate_ecobalyse.pl` is the yardstick for changes to the Ecobalyse environmental cost (ECS):
mappings, masses, transformations, packaging. Run it before and after a change, and put the
before / after numbers in the PR.

For each product of a sample, it:

1. reprocesses the product with the current code (`analyze_and_enrich_product_data`);
2. prepares the Ecobalyse food2 request (`estimate_environmental_impact_service`);
3. calls the Ecobalyse food2 API, only if `ECOBALYSE_API_TOKEN` is set. Responses are cached on disk,
   keyed by a hash of the request, so re-runs only call the API for requests that changed;
4. writes the ECS per kg, the Agribalyse EF per kg of the product category
   (`environmental_score_data.agribalyse.ef_total`), the ingredients coverage, the skip reason
   and the API error, if any.

The summary gives:

- the Spearman rank correlation of ECS/kg vs Agribalyse EF/kg;
- the number of products more than 3× away from the median ECS / Agribalyse ratio;
- the share of eligible products (enough of the ingredients mass matched to call the API);
- the API errors, grouped by message (e.g. an Ecobalyse id that the API does not know anymore);
- the worst outliers.

With `--compare previous.jsonl`, it also shows the before / after metrics and the products whose ECS changed most.

## Sample

`sample_250_fr_codes.txt` has 250 products, one per category, from the 10,000 most popular products sold in France.
All of them had enough ingredient coverage to call the API with the Ecobalyse mappings of November 2026.

The products file is a JSONL export of the products (e.g. from the MongoDB dump at
https://world.openfoodfacts.org/data, filtered on the codes). Only lines with one of the codes are decoded.

## Usage

Run it in the backend container, from the root of the repository (or worktree):

```bash
docker exec -w /opt/product-opener po_off-backend-1 \
  perl -I/opt/product-opener/lib external-data/ecobalyse/validation/validate_ecobalyse.pl \
  --codes external-data/ecobalyse/validation/sample_250_fr_codes.txt \
  --products external-data/ecobalyse/validation/runs/products.jsonl \
  --output external-data/ecobalyse/validation/runs/after.jsonl \
  --compare external-data/ecobalyse/validation/runs/before.jsonl
```

To show the summary of existing results without reprocessing:

```bash
docker exec -w /opt/product-opener po_off-backend-1 \
  perl -I/opt/product-opener/lib external-data/ecobalyse/validation/validate_ecobalyse.pl \
  --summary external-data/ecobalyse/validation/runs/after.jsonl \
  --compare external-data/ecobalyse/validation/runs/before.jsonl
```

The `runs/` directory (results, products, API cache) is ignored by git.

Notes:

- The script turns off `ecobalyse_call_api_on_product_update` while reprocessing, so that the API is called
  only once per product, through the cache.
- Temporary API errors (5xx, timeouts, authentication, rate limiting) are not cached.
- Ecobalyse rejects the whole request when one id is unknown, and reports only the first unknown id:
  after an Ecobalyse data update, check the API errors before comparing correlations, as the set of
  compared products changes.
- `--summary` and `--compare` also read the products files of the earlier analysis scripts
  (fields `ecs_100`, `agb_ef`).
