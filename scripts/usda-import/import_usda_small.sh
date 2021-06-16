#!/bin/sh

./import_csv_file.pl --csv_file /srv2/stephane/usda-202104/merged_joined_category.100.converted.csv --user_id database-usda --comment "USDA Branded Foods 2021-04 import" --source_id "database-usda" --source_name "database-usda" --manufacturer --use_brand_owner_as_org_name --define lc=en --define countries=us --source_url "https://fdc.nal.usda.gov/" --define data_sources="Database - USDA"

