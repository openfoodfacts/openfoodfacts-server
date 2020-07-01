#!/bin/sh

cd /srv/off-pro/scripts/equadis-import

# copy files modified in the last few days

rm -rf equadis-data
mkdir equadis-data
find /home/sftp/equadis/data/ -mtime -5 -type f -exec cp {} ./equadis-data/ \;

# turn Equadis xml files into an OFF CSV file
# run npm link each time, as it seems that running npm install in /srv/off-pro
# breaks the link to the local xml2csv

export NPM_CONFIG_PREFIX=~/.npm-global
npm link xml2csv

node equadis-xml2csv.js
./equadis2off.sh > equadis-data.tsv
./dereference.sh equadis-data.tsv

# import CSV file

export PERL5LIB=/srv/off-pro/lib
/srv/off-pro/scripts/import_csv_file.pl --user_id equadis --org_id equadis --source_id equadis --source_name Equadis --source_url https://equadis.com/ --manufacturer 1 --comment "Import from Equadis" --define lc=fr --images_download_dir /srv/off-pro/scripts/tmp --csv_file /srv/off-pro/scripts/equadis-import/equadis-data.tsv
