#!/bin/sh

cd /srv/off-pro/scripts

# copy files modified in the last few days

rm -rf /srv2/off-pro/bayard-data-tmp
mkdir /srv2/off-pro/bayard-data-tmp
find /home/sftp/bayard/data/ -mtime -2 -type f -exec cp {} /srv2/off-pro/bayard-data-tmp/ \;

# turn Bayard xml files into JSON file

export NPM_CONFIG_PREFIX=~/.npm-global

node /srv/off-pro/scripts/convert_gs1_xml_to_json_in_dir.js /srv2/off-pro/bayard-data-tmp/

# convert JSON files to a single CSV file

export PERL5LIB=.

/srv/off-pro/scripts/convert_gs1_json_to_off_csv.pl --input-dir /srv2/off-pro/bayard-data-tmp --output /srv2/off-pro/bayard-data-tmp/bayard-data.tsv

# import CSV file

export PERL5LIB="/srv/off-pro/lib:${PERL5LIB}"
/srv/off-pro/scripts/import_csv_file.pl --user_id bayard --org_id bayard --source_id bayard --source_name Bayard --source_url https://bayard.com/ --manufacturer 1 --comment "Import from Bayard" --define lc=de --images_download_dir /srv2/off-pro/bayard-images-tmp --csv_file /srv2/off-pro/bayard-data-tmp/bayard-data.tsv
