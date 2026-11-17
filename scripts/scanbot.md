# scanbot: scan statistics from the apps

`scanbot.pl` computes how many times each product was scanned with the Open Food Facts apps during a year, and in which countries.
It reads web server logs filtered to keep only the app scans, and:

- writes the scans of the year in the `scans.json` file of each product (scans, unique scans, unique scans and rank by country),
  and the totals for all products in `all_products_scans.json` (`--update-scans`)
- sets `scans_n` and `unique_scans_n` on the product, and the `popularity_tags` of the year,
  e.g. `top-1000-scans-2026`, `top-100-fr-scans-2026`, `top-country-fr-scans-2026`, `at-least-5-scans-2026` (`--update-popularity`)
- adds a country to products scanned by at least 5 different IPs from that country (`--add-countries`, needs `--update-popularity`).
  The country is added to the default source, so users can remove it like any other country.
  Countries are not added to products with codes starting with 2 (internal codes that can be reused in different countries).
  When countries are added, a summary is posted to the `#bots-alerts` Slack channel.

Scans of products that do not exist are counted for the totals and the percentiles (e.g. `top-90-percent-scans-2026`), but the products are not created.

A unique scan is a distinct IP address that scanned the product during the year. The country of the IP comes from GeoIP.

## Outputs

In `$BASE_DIRS{PRIVATE_DATA}/scanbot.<year>/` (`/srv/off/data/scanbot.<year>/` in production):

- `scanbot.<year>.products.csv`: one line per scanned code: code, scans, unique scans, FOUND / NOT_FOUND, source (crowdsourcing / producers), countries added, and the countries of the scans (`country:fr ...`, for grepping).
  Used by `add_nutriscore_to_scanbot_csv.pl` to compute Nutri-Score and Green-Score statistics of scanned products:

  ```bash
  grep country:fr scanbot.2026.products.csv | ./add_nutriscore_to_scanbot_csv.pl > scanbot.2026.fr.nutriscore.products.csv
  ```

- `scanbot.log`: one line per product with its scans and the countries added
- `scanbot.<year>.state.sto`: scan data and popularity tags of each product, used by incremental runs
- `scanbot.<year>.geoip.sto`: GeoIP results (IP -> country code), reused by incremental runs

## Getting the scan files

### Apache access logs (2025 and later)

On the production server, the Apache access logs of the `priority` (port 8002) and standard (port 8001) instances are in `/srv/off/logs/`
(a symlink to `/mnt/off/logs/off`: add a trailing slash when using `find`).
They are rotated daily just after midnight, kept for 2 years, and compressed except for the most recent ones:

- `access_800x.log`: current day (still being written: do not extract it, or you will count its scans twice)
- `access_800x.log.1`: previous day, uncompressed
- `access_800x.log.N.gz`: N days ago (numbers shift every day, so use the modification date of the files to know which day they contain)

Scans from the official app have "Smoothie" in the user agent and "- scan" in the request.
Filter on the year, as the first rotated files of a year also contain lines from the previous year (and the last ones lines from the next year).

To extract the scans of the whole year so far (here 2026) in `/srv/off/logs/scanbot-2026`:

```bash
cd /srv/off/logs/scanbot-2026
for p in 8001 8002; do
  find /srv/off/logs/ -maxdepth 1 -name "access_$p.log.*" ! -name "*.scan" -newermt "2026-01-01 00:00" | while read f; do
    out="access_$p.$(date -r "$f" +%F).scan"
    [ -e "$out" ] || zgrep -hE "Smoothie .* - scan" "$f" | grep -E "\[[0-9]{2}/[A-Za-z]{3}/2026:" > "$out"
  done
done
```

Each `.scan` file is named after the rotation date of its log (so it contains the logs of the previous day), and files that already exist are skipped:
the same command can be run again later to extract only the logs rotated since the last extraction.
Use `nohup nice` for a full year: it takes a while.

Since mid-July 2026, the IP field of the logs is a list of forwarded IPs (e.g. `1.2.3.4, 1.2.3.4`). scanbot keeps the last one, which is added by our proxies.
In practice the IPs of the list are almost always the same (0.03% of lines differ in 2026).

### Matomo (2022 - 2023, for missing days)

When logs were missing (2022, 2023), scan events were downloaded from Matomo, which only has about a third of the scans:
`utils/logs/download_matomo_logs.pl` downloads the events day by day, and `utils/logs/matomo_to_scan_logs.pl` converts them to the log format expected by scanbot.

## Running scanbot

Unique scans are counted over the whole year and products are ranked against all products,
so scanbot always needs the scan files of the whole year, even for incremental runs.

### Full run

Recomputes and rewrites every scanned product (about 2.5 hours for 1.7 million scanned codes in 2026):

```bash
cd /srv/off/logs/scanbot-2026
time nohup nice sh -c 'cat *.scan | /srv/off/scripts/scanbot.pl --year 2026 --update-popularity --update-scans --add-countries' > scanbot-run.out 2> scanbot-run.err
```

### Incremental run

To load new scans during the year (e.g. every week during a scan campaign), extract the new log files, then run with `--incremental`:

```bash
cd /srv/off/logs/scanbot-2026
time nohup nice sh -c 'cat *.scan | /srv/off/scripts/scanbot.pl --year 2026 --update-popularity --update-scans --add-countries --incremental' > scanbot-run.out 2> scanbot-run.err
```

With `--incremental`, scanbot compares each product with the state saved by the previous run (full or incremental) for the same year:

- products whose scans, unique scans, unique scans by country and popularity tags of the year did not change are skipped
  (no product, `scans.json`, MongoDB or Redis update). Changes of ranks alone (because other products got more scans) do not update a product,
  so ranks in `scans.json` can be slightly out of date until the next full run.
- countries are only added when they reach 5 unique scans since the previous run, so that countries removed by users are not added again
- GeoIP results of the previous run are reused

The options `--update-popularity`, `--update-scans` and `--add-countries` must be the same as in the previous run, or scanbot stops.

If there is no state file yet (e.g. the previous run was done with an older version of scanbot), products are compared with the data of the year in their `scans.json` file.

In November 2026, an incremental run on 5.1 million scans took 13 minutes for the analysis (logs 1 min, GeoIP 2 min for 1 million IPs, countries 3 min, products 7 min),
and updated 129k of the 757k scanned products that exist, instead of rewriting all of them.

### Dry run

Add `--dry-run` to compute everything and report what would change without updating products or the state file
(the CSV and log are written with a `.dry-run` suffix, the GeoIP cache is saved). The summary is at the end of the STDERR output:

```bash
grep -E '^(Phase|Products:|Loaded|Computed)' scanbot-run.err
```

To list the countries that would be added:

```bash
awk -F'\t' '$6 !~ /^"/ {split($6, a, "\""); print a[1]}' /srv/off/data/scanbot.2026/scanbot.2026.products.csv.dry-run | tr ',' '\n' | sort | uniq -c | sort -rn | head -20
```

## After a run

- recompute the popularity sort key of products: `./update_all_products.pl --compute-sort-key`
- send the scans to off-query (needs the off-query URL and credentials in `$query_url`, visits the `scans.json` files of all products): `nice perl /srv/off/scripts/export_scans_to_query.pl` (add `resume` to resume from the last checkpoint)

## Yearly schedule

Run scanbot for the full previous year in January, on the logs of the whole year (this overwrites the data of partial runs of that year).
During the year, partial runs (e.g. for projects like FOODTURE, or scan campaigns) can be done with `--incremental`.
