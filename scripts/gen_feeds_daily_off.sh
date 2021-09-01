#!/bin/sh

DEFAULT_MOUNT_PATH=/srv/off
MOUNT_PATH="${1:-$DEFAULT_MOUNT_PATH}"
DEFAULT_ALT_MOUNT_PATH=/srv2/off
ALT_MOUNT_PATH="${2:-$DEFAULT_ALT_MOUNT_PATH}"

cd ${MOUNT_PATH}/scripts
export PERL5LIB="../lib:${PERL5LIB}"

./generate_madenearme_page.pl uk en > ${MOUNT_PATH}/html/madenearme-uk.html
./generate_madenearme_page.pl world en > ${MOUNT_PATH}/html/madenearme.html
./generate_madenearme_page.pl fr fr > ${MOUNT_PATH}/html/cestemballepresdechezvous.html

./remove_empty_products.pl
#./compute_missions.pl
./export_database.pl
./mongodb_dump.sh ${ALT_MOUNT_PATH}/html openfoodfacts 10.0.0.2 off

cd ${ALT_MOUNT_PATH}/html/data
gzip < en.openfoodfacts.org.products.rdf > en.openfoodfacts.org.products.rdf.gz
gzip < fr.openfoodfacts.org.products.rdf > fr.openfoodfacts.org.products.rdf.gz

gzip < en.openfoodfacts.org.products.csv > en.openfoodfacts.org.products.csv.gz
gzip < fr.openfoodfacts.org.products.csv > fr.openfoodfacts.org.products.csv.gz

cd ${MOUNT_PATH}/scripts
./generate_dump_for_offline_apps_off.py
cd ${ALT_MOUNT_PATH}/html/data/offline
zip en.openfoodfacts.org.products.small.csv.zip en.openfoodfacts.org.products.small.csv

# Equadis import
${MOUNT_PATH}-pro/scripts/equadis-import/run_equadis_import.sh
