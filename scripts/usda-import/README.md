Steps to load the USDA data in Open Food Facts

1. Download the USDA database

(to where, specifically? -rrk)

2. Merge the USDA csv files

(what script? -rrk)

Output: merged.csv

3. Add OFF categories

(what script? -rrk)

USDA_fdc_categories.csv maps FDC categories to OFF categories.

Output: merged_joined_categories.csv

4. Convert the file to OFF CSV format

convert_csv_file.pl is a command line tool that performs the processing that is done on the
producers platform when a CSV file is loaded and columns are mapped.

Sample script (needs to be updated with new path names etc.):

- ./usda-import/convert_usda.sh

5. Deduplicate rows

The FDC data contains multiple rows for a single product, we need to keep only the most recent data,
otherwise when we import data, we will import products several times, with different data.

Sample script (needs to be updated with new path names etc.):

- ./usda-import/deduplicate_usda.sh

6. Double check everything

The USDA data exports often change (e.g. different columns names etc.) so make sure to double check everything.

Steps below should be done on a first sample first.


7. Import the data to the producers platform

Start with a small sample, to double check everything.

Sample scripts (need to be updated with new path names etc.):

- ./usda-import/import_usda_small.sh (small sample)
- ./usda-import/import_usda.sh (small sample)

8. Export the data to the public database

Sample script:

- ./usda-import/export_usda_to_public_database.sh

