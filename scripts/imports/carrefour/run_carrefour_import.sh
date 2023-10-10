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

DATA_TMP_DIR=$OFF_CACHE_TMP_DIR/carrefour-data

# Separate image directory as we want to keep images cached for later imports
IMAGES_TMP_DIR=$OFF_CACHE_TMP_DIR/carrefour-images

SUCCESS_FILE_PATH="$OFF_PRIVATE_DATA_DIR/carrefour-import-success"

IMPORT_SINCE=$(import_since $SUCCESS_FILE_PATH)

echo "IMPORT_SINCE: $IMPORT_SINCE days"

# copy XML files modified since the last successful run
echo "Copy XML files modified since the last successful run"
rm -rf $DATA_TMP_DIR
mkdir $DATA_TMP_DIR
mkdir $DATA_TMP_DIR/data
find $OFF_SFTP_HOME_DIR/carrefour/data/ -mtime -$IMPORT_SINCE -type f -name "*.xml" -exec cp {} $DATA_TMP_DIR/data/ \;

# mv files that are not human food (cosmetics and pet food)
# TODO: we could in fact just import them in the pro platform, and dispatch them
# to Open Beauty Facts and Open Pet Food Facts later, as we do for Unilever
mkdir $DATA_TMP_DIR/data.obf
mkdir $DATA_TMP_DIR/data.opff
grep -Z -l -r '"DPH -' $DATA_TMP_DIR/data | xargs --null -I{} mv {} $DATA_TMP_DIR/data.obf/
grep -Z -l -r '"ALI - PRODUITS POUR ANIMAUX' $DATA_TMP_DIR/data | xargs --null -I{} mv {} $DATA_TMP_DIR/data.opff/

# Warning some Carrefour XML files are broken with 2 <TabNutXMLPF>.*</TabNutXMLPF>
# fix them by removing the second one:
find $DATA_TMP_DIR/data/ -name "*.xml" -type f -exec sed -i 's/<\/TabNutXMLPF><TabNutXMLPF>.*/<\/TabNutXMLPF>/g' {} \;

# Unzip images
# TODO: we get images from time to time in .zip files, but the .xml files we get
# for products could have images from earlier zip files, so currently we unzip
# all images we got.
# Carrefour will soon send us CSV files with images urls, so this process will
# eventually be replaced (i.e. not worth improving it now)
# create the images dir if it does not exist yet
mkdir -p $IMAGES_TMP_DIR
# unzip -j: create all files in destination folder, without any path
unzip -j -o "$OFF_SFTP_HOME_DIR/carrefour/data/*.zip" -d "$IMAGES_TMP_DIR/"
# copy images.rules used to determine the image type from the image file name
cp ./scripts/imports/carrefour/images.rules $IMAGES_TMP_DIR

# Convert Carrefour XML files to one OFF csv file
echo "Convert Carrefour XML files to OFF csv file"
./scripts/imports/carrefour/convert_carrefour_data.pl $DATA_TMP_DIR/data ./scripts/imports/carrefour/Nomenclature_OpenFoodFacts.csv > $DATA_TMP_DIR/carrefour-data.tsv || exit 101;

# Note: for testing, we can import products under the carrefour-test-off2 org

# import data
echo "Import data"
./scripts/import_csv_file.pl --csv_file $DATA_TMP_DIR/carrefour-data.tsv --user_id carrefour --comment "Import Carrefour" --source_id "carrefour" --source_name "Carrefour" --source_url "https://www.carrefour.fr" --manufacturer --org_id carrefour-test-off2 --define lc=fr --images_dir $IMAGES_TMP_DIR

# mark successful run
mark_successful_run $SUCCESS_FILE_PATH
