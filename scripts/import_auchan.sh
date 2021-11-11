#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./import_csv_file.pl --csv_file /srv/off/imports/auchan/auchan.csv --user_id auchan --comment "Import Auchan" --source_id "auchan" --source_name "Auchan" --source_url "https://www.auchan.fr" --images_dir /srv/off/imports/auchan/images --manufacturer --skip_products_without_info
