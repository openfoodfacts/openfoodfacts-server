#!/usr/bin/env bash

# do not continue on failure
set -e

# load utils
. scripts/imports/imports_utils.sh

# this script must be launch from server root (/srv/off-pro)
export PERL5LIB=lib:$PERL5LIB

# load paths
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

if [[ -z "OFF_SFTP_HOME_DIR" ]]
then
    >&2 "SFTP_HOME not defined, exiting"
fi

DATA_TMP_DIR=$OFF_CACHE_TMP_DIR/equadis-data
IMAGES_TMP_DIR=$OFF_CACHE_TMP_DIR/equadis-images

SUCCESS_FILE_PATH="$OFF_PRIVATE_DATA_DIR/equadis-import-success"

IMPORT_SINCE=$(import_since $SUCCESS_FILE_PATH)

echo "IMPORT_SINCE: $IMPORT_SINCE"

# copy files modified in the last succesful run
rm -rf $DATA_TMP_DIR
mkdir $DATA_TMP_DIR
find $OFF_SFTP_HOME_DIR/equadis/data/ -mtime -$IMPORT_SINCE -type f -exec cp {} $DATA_TMP_DIR/ \;

# turn Equadis xml files into JSON file
./scripts/convert_gs1_xml_to_json_in_dir.pl $DATA_TMP_DIR || exit 100;

# convert JSON files to a single CSV file
./scripts/convert_gs1_json_to_off_csv.pl --input-dir $DATA_TMP_DIR --output $DATA_TMP_DIR/equadis-data.tsv || exit 101;

# STOP here to test !
exit 1

# import CSV file
./scripts/import_csv_file.pl \
    --user_id equadis --org_id equadis --source_id equadis --source_name Equadis \
    --source_url https://equadis.com/ --manufacturer 1 --comment "Import from Equadis" \
    --define lc=fr --images_download_dir $IMAGES_TMP_DIR --csv_file $DATA_TMP_DIR/equadis-data.tsv  || exit 102

# mark successful run
mark_successful_run $SUCCESS_FILE_PATH
