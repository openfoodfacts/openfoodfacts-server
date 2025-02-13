#!/bin/sh

cd /srv/off-pro/scripts/codeonline-import

rm -rf /srv2/off-pro/codeonline-data-tmp
mkdir /srv2/off-pro/codeonline-data-tmp
cp -a /srv/off/imports/codeonline/import/. /srv2/off-pro/codeonline-data-tmp/

# convert JSON files to a single CSV file

cd /srv/off-pro/scripts
export PERL5LIB=.

/srv/off-pro/scripts/convert_gs1_json_to_off_csv.pl --input-dir /srv2/off-pro/codeonline-data-tmp --output /srv2/off-pro/codeonline-data-tmp/codeonline-data.tsv

# import CSV file

export PERL5LIB="/srv/off-pro/lib:${PERL5LIB}"
/srv/off-pro/scripts/import_csv_file.pl --user_id codeonline --org_id codeonline --source_id codeonline --source_name CodeOnline --source_url https://codeonline.fr/ --manufacturer 1 --comment "Import from CodeOnline" --define lc=fr --images_download_dir /srv2/off-pro/codeonline-images-tmp --csv_file /srv2/off-pro/codeonline-data-tmp/codeonline-data.tsv
