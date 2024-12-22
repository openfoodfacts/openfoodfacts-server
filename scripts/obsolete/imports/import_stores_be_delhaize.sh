#!/bin/sh
./import_csv_file.pl --csv_file /srv/off/imports/stores/be_delhaize_20190228.csv --user_id countrybot --comment "Products sold in Belgium" --no_source --import_lc fr --skip_not_existing_products --define countries="en:belgium" --define stores="Delhaize"
