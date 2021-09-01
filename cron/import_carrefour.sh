#!/bin/sh

DEFAULT_MOUNT_PATH=/srv/off
MOUNT_PATH="${1:-$DEFAULT_MOUNT_PATH}"

cp -a /home/sftp/carrefour/data/*xml ${MOUNT_PATH}/imports/carrefour/data/

cd ${MOUNT_PATH}/imports/carrefour

./mv_non_off_files.sh

# Warning some Carrefour XML files are broken with 2 <TabNutXMLPF>.*</TabNutXMLPF>
# fix them by removing the second one:
cd data
find . -name "*.xml" -type f -exec sed -i 's/<\/TabNutXMLPF><TabNutXMLPF>.*/<\/TabNutXMLPF>/g' {} \;

unzip -o '/home/sftp/carrefour/data/*zip' -d ${MOUNT_PATH}/imports/carrefour/images/

cd ${MOUNT_PATH}-pro/scripts

export PERL5LIB=.

./convert_carrefour_data_off1.sh

./import_carrefour_pro_off1.sh

./export_csv_file.pl --fields code,nutrition_grades_tags --query editors_tags=carrefour --separator ';' > ${MOUNT_PATH}/html/data/exports/carrefour_nutriscore.csv

./export_csv_file.pl --fields code,nutrition_grades_tags --separator ';' > ${MOUNT_PATH}/html/data/exports/nutriscore.csv
