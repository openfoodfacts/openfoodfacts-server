#!/bin/sh

cd /srv/off-pro/scripts/equadis-import

# copy files modified in the last few days

rm -rf /srv2/off-pro/equadis-data-tmp
mkdir /srv2/off-pro/equadis-data-tmp
find /home/sftp/equadis/data/ -mtime -2 -type f -exec cp {} /srv2/off-pro/equadis-data-tmp/ \;

# turn Equadis xml files into an OFF CSV file
# run npm link each time, as it seems that running npm install in /srv/off-pro
# breaks the link to the local xml2csv

export NPM_CONFIG_PREFIX=~/.npm-global
npm link xml2csv

node equadis-xml2csv.js
./equadis2off.sh > /srv2/off-pro/equadis-data-tmp/equadis-data.tsv
./dereference.sh /srv2/off-pro/equadis-data-tmp/equadis-data.tsv

# import CSV file

export PERL5LIB="/srv/off-pro/lib:${PERL5LIB}"
/srv/off-pro/scripts/import_csv_file.pl --user_id equadis --org_id equadis --source_id equadis --source_name Equadis --source_url https://equadis.com/ --manufacturer 1 --comment "Import from Equadis" --define lc=fr --images_download_dir /srv2/off-pro/equadis-images-tmp --csv_file /srv2/off-pro/equadis-data-tmp/equadis-data.tsv
