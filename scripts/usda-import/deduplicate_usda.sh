#!/bin/sh

# keep only the most recent entry

python keep_most_recent_row_for_each_product.py /srv2/stephane/usda-202104/merged_joined_category.converted.csv > /srv2/stephane/usda-202104/merged_joined_category.converted.unique.csv
