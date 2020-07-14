#!/bin/sh

./import_csv_file.pl --csv_file /srv2/off/imports/scamark/scamark.csv --user_id scamark --comment "Import Scamark" --source_id "scamark" --source_name "Scamark" --source_url "https://www.scamark.com" --images_dir /srv2/off/imports/scamark/images/jpg --manufacturer --define data_sources="Producers, Producer - Scamark"

