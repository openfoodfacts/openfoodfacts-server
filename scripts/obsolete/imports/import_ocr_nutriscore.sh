#!/bin/sh
./import_csv_file.pl --csv_file /srv/off/imports/ocr/nutriscore/nutriscore.csv --user_id ocr-nutriscore --comment "Nutri-Score label" --no_source --import_lc fr --skip_not_existing_products

