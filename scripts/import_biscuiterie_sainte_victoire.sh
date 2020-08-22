#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./import_csv_file.pl --csv_file /srv2/off/imports/biscuiterie-sainte-victoire/biscuiterie-sainte-victoire.csv --user_id biscuiterie-sainte-victoire --comment "Import Biscuiterie Sainte-Victoire" --source_id "biscuiterie-sainte-victoire" --source_name "Biscuiterie Sainte-Victoire" --source_url "https://www.biscuiterie-sainte-victoire.com" --images_dir /srv2/off/imports/biscuiterie-sainte-victoire/images --manufacturer --define countries=en:france
