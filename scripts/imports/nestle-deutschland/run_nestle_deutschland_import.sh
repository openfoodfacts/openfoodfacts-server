#!/usr/bin/env bash

# do not continue on failure
set -e

# load utils
. scripts/imports/imports_utils.sh

# this script must be launched from server root (/srv/off-pro)
export PERL5LIB=lib:$PERL5LIB

# load paths
echo "Load paths"
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

if [[ -z "$OFF_SFTP_HOME_DIR" ]]
then
    >&2 "OFF_SFTP_HOME_DIR not defined, exiting"
    exit 10
fi

DATA_TMP_DIR=$OFF_CACHE_TMP_DIR/nestle-deutschland-data

# Separate image directory
IMAGES_TMP_DIR=$OFF_CACHE_TMP_DIR/nestle-deutschland-images

SUCCESS_FILE_PATH="$OFF_PRIVATE_DATA_DIR/nestle-deutschland-import-success"

IMPORT_SINCE=$(import_since $SUCCESS_FILE_PATH)

echo "IMPORT_SINCE: $IMPORT_SINCE days"

# We do not keep already processed files in the sftp
# directory, we move them to a different place, but still keep past files
# in case we need to reprocess them
echo "Copy csv and image files to $OFF_SFTP_HOME_DIR/nestledeutschland-backup/data/"
# Note: the "cp -a" flag results in an error if the files are owned by different users
# removing it as it is making this script too fragile
cp -r $OFF_SFTP_HOME_DIR/nestledeutschland/data/ $OFF_SFTP_HOME_DIR/nestledeutschland-backup/

# copy CSV files modified since the last successful run
echo "Move CSV files modified since the last successful run"
rm -rf $DATA_TMP_DIR
mkdir $DATA_TMP_DIR
mkdir $DATA_TMP_DIR/data
rm -rf $IMAGES_TMP_DIR
mkdir -p $IMAGES_TMP_DIR
mkdir -p $IMAGES_TMP_DIR/tmp

find $OFF_SFTP_HOME_DIR/nestledeutschland/data -mtime -$IMPORT_SINCE -type f -name "*.xlsx" -exec cp {} $DATA_TMP_DIR/data/ \;

# convert and import CSV files in alphabetical order
echo "Convert and import data"

# Enable nullglob to prevent errors when no files are found
shopt -s nullglob

for file in $DATA_TMP_DIR/data/*xlsx; do
    echo "Importing $file"
    # We use convert_csv_file.pl to convert the XLSX file to the OFF CSV file format
    # for that to work, we first need to import the file on the pro platform once, so that we can select the input columns and match them to OFF columns
    # the resulting mapping file has then been saved in the scripts/import/nestle-deutschland/ directory
    ./scripts/convert_csv_file.pl --csv "$file" --columns_fields_file scripts/imports/nestle-deutschland/all_columns_fields.sto --converted "$file.converted" --define countries=en:germany --define lc=de
    ./scripts/import_csv_file.pl --csv_file "$file.converted" --user_id nestle-deutschland --comment "Import Nestlé Deutschland" --source_id "nestle-deutschland" --source_name "Nestlé Deutschland" --source_url "https://www.nestle.de/" --manufacturer --org_id nestle-deutschland --define lc=de --images_download_dir $IMAGES_TMP_DIR
done

echo "Removing processed files"

# Remove the files from the sftp when they have been successfully processed
# note: the data directory needs permission 775
find $OFF_SFTP_HOME_DIR/nestledeutschland/data -mtime -$IMPORT_SINCE -type f -name "*.xlsx" -exec mv {} $DATA_TMP_DIR/data/ \;

# mark successful run
mark_successful_run $SUCCESS_FILE_PATH
