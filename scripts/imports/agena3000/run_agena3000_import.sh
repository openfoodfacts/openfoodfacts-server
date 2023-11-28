#!/usr/bin/env bash
# do not continue on failure
set -e

# load utils
. scripts/imports/imports_utils.sh

# this script must be launch from server root (/srv/off-pro)
export PERL5LIB=lib:$PERL5LIB

# load paths
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

if [[ -z "$OFF_SFTP_HOME_DIR" ]]
then
    >&2 echo "SFTP_HOME not defined, exiting"
    exit 10
fi

# Mirror data from Agena3000's server
# access needs to be configured in ~/.netrc
declare -x LFTP_HOME=$OFF_PRIVATE_DATA_DIR/secrets/

# copy files from Agena3000's server (mirroring)
lftp -c "set cmd:default-protocol sftp; open sftp-a3dm.agena3000.com:2222; mirror --Remove-source-files /PROD/Fiches/ $OFF_SFTP_HOME_DIR/agena3000/PROD/Fiches/"

# copy files modified since last run
DATA_TMP_DIR=$OFF_CACHE_TMP_DIR/agena3000-data

SUCCESS_FILE_PATH="$OFF_PRIVATE_DATA_DIR/agena3000-import-success"

IMPORT_SINCE=$(import_since $SUCCESS_FILE_PATH)

# copy files modified in the last succesful run
rm -rf $DATA_TMP_DIR
mkdir $DATA_TMP_DIR
find $OFF_SFTP_HOME_DIR/agena3000/PROD/Fiches/ -mtime -$IMPORT_SINCE -type f -exec cp {} $DATA_TMP_DIR/ \;

# turn GS1 XML files into JSON file
./scripts/convert_gs1_xml_to_json_in_dir.pl $DATA_TMP_DIR || exit 100;

# convert JSON files to a single CSV file
./scripts/convert_gs1_json_to_off_csv.pl \
    --input-dir $DATA_TMP_DIR --output $DATA_TMP_DIR/agena3000-data.tsv \
    --confirmation-dir $DATA_TMP_DIR/Ack

# STOP here to test !
# exit 1

# import CSV file
./scripts/import_csv_file.pl \
    --user_id agena3000 --org_id agena3000 --source_id agena3000 \
    --source_name Agena3000 --source_url https://agena3000.com/ \
    --manufacturer 1 --comment "Import from Agena3000" --define lc=fr \
    --images_download_dir $DATA_TMP_DIR \
    --csv_file $DATA_TMP_DIR/agena3000-data.tsv

# Send confirmation messages to Agena3000
lftp -c "set cmd:default-protocol sftp; open sftp-a3dm.agena3000.com:2222; mirror -R --Remove-source-files $DATA_TMP_DIR/Ack/ /PROD/Ack/"

# mark sucessful run
mark_successful_run $SUCCESS_FILE_PATH
