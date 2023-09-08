#!/bin/sh

# do not continue on failure
set -e

# this script must be launch from server root (/srv/off-pro)
export PERL5LIB=lib/ProductOpener:$PERL5LIB

# load paths
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

DATA_TMP_DIR=$OFF_CACHE_TMP_DIR/equadis-data
IMAGES_TMP_DIR=$OFF_CACHE_TMP_DIR/equadis-images

# find last run and deduce how many days to fetch
if [[ -f "$OFF_PRIVATE_DATA_DIR/equadis-import-success" ]]
then
    LAST_TS=$(cat $OFF_PRIVATE_DATA_DIR/equadis-import-success)
    CURRENT_TS=$(date +%s)
    DIFF=$(( $CURRENT_TS - $LAST_TS ))
    # 86400 seconds in a day, +1 because we want upper bound
    IMPORT_SINCE=$(( $DIFF / 86400 + 1 ))
else
    # defaults to one week
    IMPORT_SINCE=7
fi

# copy files modified in the last few days
rm -rf $DATA_TMP_DIR
mkdir $DATA_TMP_DIR
find $OFF_SFTP_HOME_DIR/equadis/data/ -mtime -$IMPORT_SINCE -type f -exec cp {} $DATA_TMP_DIR/ \;

# turn Equadis xml files into JSON file
./scripts/convert_gs1_xml_to_json_in_dir.pl $DATA_TMP_DIR || exit 100;

# convert JSON files to a single CSV file
./scripts/convert_gs1_json_to_off_csv.pl --input-dir $DATA_TMP_DIR --output $DATA_TMP_DIR/equadis-data.tsv || exit 101;

# import CSV file
./scripts/import_csv_file.pl \
    --user_id equadis --org_id equadis --source_id equadis --source_name Equadis \
    --source_url https://equadis.com/ --manufacturer 1 --comment "Import from Equadis" \
    --define lc=fr --images_download_dir $IMAGES_TMP_DIR --csv_file $DATA_TMP_DIR/equadis-data.tsv  || exit 102

# mark successful run
echo $(date +%s) > $OFF_PRIVATE_DATA_DIR/equadis-import-success