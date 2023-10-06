#!/usr/bin/env bash

# do not continue on failure
set -e

# load utils
. scripts/imports/imports_utils.sh

# this script must be launched from server root (/srv/off-pro)
export PERL5LIB=lib:$PERL5LIB

# load paths
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

if [[ -z "$OFF_SFTP_HOME_DIR" ]]
then
    >&2 "OFF_SFTP_HOME_DIR not defined, exiting"
fi

DATA_TMP_DIR=$OFF_CACHE_TMP_DIR/carrefour-data
IMAGES_TMP_DIR=$OFF_CACHE_TMP_DIR/carrefour-images

SUCCESS_FILE_PATH="$OFF_PRIVATE_DATA_DIR/carrefour-import-success"

IMPORT_SINCE=$(import_since $SUCCESS_FILE_PATH)

echo "IMPORT_SINCE: $IMPORT_SINCE days"

# copy XML files modified in the last successful run
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
mkdir $DATA_TMP_DIR/images
unzip -o "$OFF_SFTP_HOME_DIR/carrefour/data/*.zip" -d "$DATA_TMP_DIR/images/"

# Convert Carrefour XML files to one OFF csv file
./scripts/imports/carrefour/convert_carrefour_data.pl $DATA_TMP_DIR/data ./scripts/imports/carrefour/Nomenclature_OpenFoodFacts.csv > $DATA_TMP_DIR/carrefour-data.tsv || exit 101;

# Note: for testing, we can import products under the carrefour-test-off2 org

./scripts/import_csv_file.pl --csv_file $DATA_TMP_DIR/carrefour-data.tsv --user_id carrefour --comment "Import Carrefour" --source_id "carrefour" --source_name "Carrefour" --source_url "https://www.carrefour.fr" --manufacturer --org_id carrefour --define lc=fr 

./scripts/export_csv_file.pl --fields code,nutrition_grades_tags --query editors_tags=carrefour --separator ';' > $OFF_PUBLIC_DATA_DIR/exports/carrefour_nutriscore.csv

./scripts/export_csv_file.pl --fields code,nutrition_grades_tags --separator ';' > $OFF_PUBLIC_DATA_DIR/exports/nutriscore.csv

# mark successful run
mark_successful_run $SUCCESS_FILE_PATH
