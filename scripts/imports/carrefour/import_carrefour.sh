#!/bin/sh

# do not continue on failure
set -e

# load utils
. scripts/imports/imports_utils.sh

# this script must be launch from server root (/srv/off-pro)
export PERL5LIB=lib/ProductOpener:$PERL5LIB

# load paths
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(realpath $SCRIPT_DIR)

cp -a /home/sftp/carrefour/data/*xml /srv/off/imports/carrefour/data/

cd /srv/off/imports/carrefour

# mv non off files
grep -Z -l -r '"DPH -' data | xargs --null -I{} mv {} data.obf/
grep -Z -l -r '"ALI - PRODUITS POUR ANIMAUX' data | xargs --null -I{} mv {} data.opff/

# Warning some Carrefour XML files are broken with 2 <TabNutXMLPF>.*</TabNutXMLPF>
# fix them by removing the second one:
cd data
find . -name "*.xml" -type f -exec sed -i 's/<\/TabNutXMLPF><TabNutXMLPF>.*/<\/TabNutXMLPF>/g' {} \;

unzip -o '/home/sftp/carrefour/data/*zip' -d /srv/off/imports/carrefour/images/

cd $SCRIPT_DIR

export PERL5LIB=../lib

./convert_carrefour_data_off1.sh

./import_carrefour_pro_off1.sh

./export_csv_file.pl --fields code,nutrition_grades_tags --query editors_tags=carrefour --separator ';' > /srv/off/html/data/exports/carrefour_nutriscore.csv

./export_csv_file.pl --fields code,nutrition_grades_tags --separator ';' > /srv/off/html/data/exports/nutriscore.csv
