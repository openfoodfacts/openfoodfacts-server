#!/bin/sh

./import_csv_file.pl --csv_file /srv2/off/imports/barilla/harrys.csv --user_id barilla --comment "Import Barilla" --source_id "barilla" --source_name "Barilla" --source_url "https://www.barilla.com/fr-fr" --images_dir /srv2/off/imports/barilla/images --manufacturer --define data_sources="Producers, Producer - Barilla"

