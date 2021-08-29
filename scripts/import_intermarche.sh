#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./import_csv_file.pl --csv_file /srv2/off/imports/intermarche/intermarche.csv --user_id mousquetaires --comment "Import Mousquetaires" --source_id "mousquetaires" --source_name "Mousquetaires" --source_url "https://www.mousquetaires.com" --images_dir /srv2/off/imports/intermarche/images --manufacturer
