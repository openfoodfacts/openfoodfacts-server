#!/bin/sh

# Mirror data from Agena3000's server
# access needs to be configured in ~/.netrc
lftp -c "set cmd:default-protocol sftp; open sftp-a3dm.agena3000.com:2222; mirror --Remove-source-files /PROD/Fiches/ /home/sftp/agena3000/PROD/Fiches/"

cd /srv/off-pro/scripts

# copy files modified in the last few days

rm -rf /srv2/off-pro/agena3000-data-tmp
mkdir /srv2/off-pro/agena3000-data-tmp
find /home/sftp/agena3000/PROD/Fiches/ -mtime -2 -type f -exec cp {} /srv2/off-pro/agena3000-data-tmp/ \;

# turn GS1 XML files into JSON file

/srv/off-pro/scripts/convert_gs1_xml_to_json_in_dir.pl /srv2/off-pro/agena3000-data-tmp/

# convert JSON files to a single CSV file

export PERL5LIB=.

/srv/off-pro/scripts/convert_gs1_json_to_off_csv.pl --input-dir /srv2/off-pro/agena3000-data-tmp --output /srv2/off-pro/agena3000-data-tmp/agena3000-data.tsv --confirmation-dir /srv2/off-pro/agena3000-data-tmp/Ack

# import CSV file

export PERL5LIB="/srv/off-pro/lib:${PERL5LIB}"
/srv/off-pro/scripts/import_csv_file.pl --user_id agena3000 --org_id agena3000 --source_id agena3000 --source_name Agena3000 --source_url https://agena3000.com/ --manufacturer 1 --comment "Import from Agena3000" --define lc=fr --images_download_dir /srv2/off-pro/agena3000-images-tmp --csv_file /srv2/off-pro/agena3000-data-tmp/agena3000-data.tsv

# Send confirmation messages to Agena3000
lftp -c "set cmd:default-protocol sftp; open sftp-a3dm.agena3000.com:2222; mirror -R --Remove-source-files /srv2/off-pro/agena3000-data-tmp/Ack/ /PROD/Ack/"
