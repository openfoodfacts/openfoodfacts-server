#!/bin/sh
# do not continue on failure
set -e


$CUR_DIR=$(pwd)
$SCRIPT_DIR=$(dirname "$0")

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

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(realpath $SCRIPT_DIR)

# FIXME
# Not sure of this location for files (is it private data or cache data ? There are some data files like the Nomenclature_OpenFoodFacts.csv !)
# also we have to rsync data from /srv/off/imports/carrefour to this new location
exit 1

CARREFOUR_DIR=$OFF_CACHE_TMP_DIR/carrefour
DATA_TMP_DIR=$OFF_CACHE_TMP_DIR/carrefour/data
IMAGES_TMP_DIR=$OFF_CACHE_TMP_DIR/carrefour/images
mkdir -p $DATA_TMP_DIR
mkdir -p $IMAGES_TMP_DIR

# get data
cp -a $OFF_SFTP_HOME_DIR/carrefour/data/*xml $DATA_TMP_DIR/data/

# get images
unzip -o '$OFF_SFTP_HOME_DIR/carrefour/data/*zip' -d $IMAGES_TMP_DIR/carrefour/images/

cd $DATA_TMP_DIR

# ./mv_non_off_files.sh
grep -Z -l -r '"DPH -' data | xargs --null -I{} mv {} data.obf/
grep -Z -l -r '"ALI - PRODUITS POUR ANIMAUX' data | xargs --null -I{} mv {} data.opff/


# Warning some Carrefour XML files are broken with 2 <TabNutXMLPF>.*</TabNutXMLPF>
# fix them by removing the second one:
cd $DATA_TMP_DIR/data
find . -name "*.xml" -type f -exec sed -i 's/<\/TabNutXMLPF><TabNutXMLPF>.*/<\/TabNutXMLPF>/g' {} \;

cd $CUR_DIR

$SCRIPT_DIR/convert_carrefour_data.pl $DATA_TMP_DIR/data $CARREFOUR_DIR/Nomenclature_OpenFoodFacts.csv > $DATA_TMP_DIR/carrefour.csv

./import_csv_file.pl --csv_file $DATA_TMP_DIR/carrefour.csv --user_id carrefour --comment "Import Carrefour" --source_id "org-carrefour" --source_name "Carrefour" --source_url "https://www.carrefour.fr" --manufacturer --org_id carrefour --define lc=fr 

./export_csv_file.pl --fields code,nutrition_grades_tags --query editors_tags=carrefour --separator ';' > $OFF_PUBLIC_DATA_DIR/exports/carrefour_nutriscore.csv

./export_csv_file.pl --fields code,nutrition_grades_tags --separator ';' > $OFF_PUBLIC_DATA_DIR/exports/nutriscore.csv
