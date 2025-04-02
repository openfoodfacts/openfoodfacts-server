#!/usr/bin/env bash

# Carrefour France sends us CSV files containing URLs of product images through a Google Cloud storate bucket.

# do not continue on failure
#set -e

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

DATA_TMP_DIR=$OFF_CACHE_TMP_DIR/carrefour-data

# Separate image directory as we want to keep images cached for later imports
IMAGES_TMP_DIR=$OFF_CACHE_TMP_DIR/carrefour-downloaded-images

SUCCESS_FILE_PATH="$OFF_PRIVATE_DATA_DIR/carrefour-import-images-success"

IMPORT_SINCE=$(import_since $SUCCESS_FILE_PATH)

echo "IMPORT_SINCE: $IMPORT_SINCE days"

# Get new images urls CSV files from the Google Cloud storage bucket
# we use --no-clobber to get only new files

gcloud storage cp --no-clobber --recursive gs://vg1p-apps-basemedia-prd-a7_basemedia-openfoodfacts-outbound/export_openfoodfact $OFF_SFTP_HOME_DIR/carrefour/data_images/ --project vg1p-apps-basemedia-prd-a7

# copy images URLs CSV files modified since the last successful run
echo "Copy images URLs CSV files modified since the last successful run"
rm -rf $DATA_TMP_DIR
mkdir $DATA_TMP_DIR
mkdir $DATA_TMP_DIR/data_images
find $OFF_SFTP_HOME_DIR/carrefour/data_images/ -mtime -$IMPORT_SINCE -type f -name "*.csv" -exec cp {} $DATA_TMP_DIR/data_images/ \;

# Go through all the CSV files, convert them to OFF CSV files and import them


echo "Convert and import each CSV file"
for file in $DATA_TMP_DIR/data_images/*.csv; do
    # Check if the file is in the right format
    echo "Converting $file"
    # Keep only the file name
    filename="${file##*/}"
    ./scripts/imports/carrefour/convert_carrefour_data_images.pl "$DATA_TMP_DIR/data_images/${filename}" > "$DATA_TMP_DIR/data_images/${filename}.off" || exit 101;

    # import data
    echo "Importing ${filename}.off"
    ./scripts/import_csv_file.pl --csv_file "$DATA_TMP_DIR/data_images/${filename}.off" --user_id carrefour --comment "Import Carrefour Images" --source_id "carrefour" --source_name "Carrefour" --source_url "https://www.carrefour.fr" --manufacturer --org_id carrefour-images-test --define lc=fr --images_download_dir $IMAGES_TMP_DIR

    exit
done

# mark successful run
#mark_successful_run $SUCCESS_FILE_PATH
