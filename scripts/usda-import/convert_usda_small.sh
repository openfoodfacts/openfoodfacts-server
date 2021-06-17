#!/bin/sh

# match the columns of the USDA file (converted and merged with the recipe-analyzer script)
# sample script:

./convert_csv_file.pl --csv_file /srv2/stephane/usda-202104/merged_joined_category.100.csv --columns_fields_file=/srv/off-pro/import_files/org-database-usda/all_columns_fields.sto --converted_csv_file /srv2/stephane/usda-202104/merged_joined_category.100.converted.csv --source_id database-usda
