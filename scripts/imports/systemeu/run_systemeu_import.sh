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

DATA_TMP_DIR=$OFF_CACHE_TMP_DIR/systemeu-data

# Separate image directory
IMAGES_TMP_DIR=$OFF_CACHE_TMP_DIR/systemeu-images

SUCCESS_FILE_PATH="$OFF_PRIVATE_DATA_DIR/systemeu-import-success"

IMPORT_SINCE=$(import_since $SUCCESS_FILE_PATH)

echo "IMPORT_SINCE: $IMPORT_SINCE days"

# We do not keep already processed files in the sftp
# directory, we move them to a different place, but still keep past files
# in case we need to reprocess them
echo "Copy csv and image files to $OFF_SFTP_HOME_DIR/systemeu-backup/data/"
# Note: the "cp -a" flag results in an error if the files are owned by different users
# removing it as it is making this script too fragile
cp -r $OFF_SFTP_HOME_DIR/systemeu/data/ $OFF_SFTP_HOME_DIR/systemeu-backup/

# copy CSV files modified since the last successful run
echo "Move CSV files modified since the last successful run"
rm -rf $DATA_TMP_DIR
mkdir $DATA_TMP_DIR
mkdir $DATA_TMP_DIR/data
rm -rf $IMAGES_TMP_DIR
mkdir -p $IMAGES_TMP_DIR
mkdir -p $IMAGES_TMP_DIR/tmp

find $OFF_SFTP_HOME_DIR/systemeu/data -mtime -$IMPORT_SINCE -type f -name "*.csv*" -exec cp {} $DATA_TMP_DIR/data/ \;

# convert and import CSV files in alphabetical order
echo "Convert and import data"

# Enable nullglob to prevent errors when no files are found
shopt -s nullglob

for file in $DATA_TMP_DIR/data/*.csv; do
    # Intermarche files have a BOM at the start of the file, which confuses Text::CSV
    # Remove it if there is one
    sed -i '1s/^\xEF\xBB\xBF//' $file
    echo "Importing $file"
    ./scripts/imports/systemeu/convert_systemeu_csv_to_off_csv.pl $file $file.converted
    ./scripts/import_csv_file.pl --csv_file $file.converted --user_id systemeu --comment "Import Systeme U" --source_id "systemeu" --source_name "Systeme U" --source_url "https://www.magasins-u.com/" --manufacturer --org_id systeme-u --define lc=fr --images_dir $IMAGES_TMP_DIR/tmp
done

# Remove the files from the sftp when they have been successfully processed
find $OFF_SFTP_HOME_DIR/systemeu/data -mtime -$IMPORT_SINCE -type f -name "*.csv" -exec mv {} $DATA_TMP_DIR/data/ \;

# Copy ZIP files containing images
find $OFF_SFTP_HOME_DIR/systemeu/data -mtime -$IMPORT_SINCE -type f -name "*.zip" -exec cp {} $DATA_TMP_DIR/data/ \;

# Unzip image files in alphabetical order and import them
echo "Unzip and import images"
for file in $DATA_TMP_DIR/data/*.zip; do
    echo "Unzipping $file to $IMAGES_TMP_DIR"
    rm -rf $IMAGES_TMP_DIR
    mkdir -p $IMAGES_TMP_DIR
    mkdir -p $IMAGES_TMP_DIR/tmp
    unzip -j -u -o "$file" -d $IMAGES_TMP_DIR/tmp
    ./scripts/imports/systemeu/convert_systemeu_images_to_off_csv.pl $IMAGES_TMP_DIR $file.images.converted
    ./scripts/import_csv_file.pl --csv_file $file.images.converted --user_id systemeu --comment "Import Systeme U - Images" --source_id "systemeu" --source_name "Systeme U" --source_url "https://www.magasins-u.com/" --manufacturer --org_id systeme-u --define lc=fr --images_dir $IMAGES_TMP_DIR/tmp
done

# Remove the files from the sftp when they have been successfully processed
find $OFF_SFTP_HOME_DIR/systemeu/data -mtime -$IMPORT_SINCE -type f -name "*.zip" -exec mv {} $DATA_TMP_DIR/data/ \;

# mark successful run
mark_successful_run $SUCCESS_FILE_PATH
