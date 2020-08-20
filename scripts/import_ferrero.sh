#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./import_csv_file.pl --csv_file /srv/off/imports/ferrero/ferrero_janvier_2019.csv --user_id ferrero --comment "Import Ferrero" --source_id "ferrero" --source_name "Ferrero" --source_url "https://www.ferrero.fr" --images_dir /srv/off/imports/ferrero/images --manufacturer --skip_products_without_info
