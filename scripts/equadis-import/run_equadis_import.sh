#!/bin/sh

cd /srv/off-pro/scripts

# copy files modified in the last few days

rm -rf /srv2/off-pro/equadis-data-tmp
mkdir /srv2/off-pro/equadis-data-tmp
find /home/sftp/equadis/data/ -mtime -2 -type f -exec cp {} /srv2/off-pro/equadis-data-tmp/ \;

# turn Equadis xml files into JSON file

export NPM_CONFIG_PREFIX=~/.npm-global

node /srv/off-pro/scripts/convert_gs1_xml_to_json_in_dir.js /srv2/off-pro/equadis-data-tmp/

# convert JSON files to a single CSV file

export PERL5LIB=.

/srv/off-pro/scripts/convert_gs1_json_to_off_csv.pl --input-dir /srv2/off-pro/equadis-data-tmp --output /srv2/off-pro/equadis-data-tmp/equadis-data.tsv

# import CSV file

export PERL5LIB="/srv/off-pro/lib:${PERL5LIB}"
/srv/off-pro/scripts/import_csv_file.pl --user_id equadis --org_id equadis --source_id equadis --source_name Equadis --source_url https://equadis.com/ --manufacturer 1 --comment "Import from Equadis" --define lc=fr --images_download_dir /srv2/off-pro/equadis-images-tmp --csv_file /srv2/off-pro/equadis-data-tmp/equadis-data.tsv
