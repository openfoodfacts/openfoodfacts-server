#!/bin/sh

cd /srv/off/scripts
./remove_empty_products.pl
#./compute_missions.pl
./export_database.pl
./mongodb_dump.sh /srv2/off/html openfoodfacts 10.0.0.2 off

cd /srv2/off/html/data
gzip < en.openfoodfacts.org.products.rdf > en.openfoodfacts.org.products.rdf.gz
gzip < fr.openfoodfacts.org.products.rdf > fr.openfoodfacts.org.products.rdf.gz

gzip < en.openfoodfacts.org.products.csv > en.openfoodfacts.org.products.csv.gz
gzip < fr.openfoodfacts.org.products.csv > fr.openfoodfacts.org.products.csv.gz

cd /srv/off/scripts
./generate_dump_for_offline_apps_off.py
cd /srv2/off/html/data/offline
zip en.openfoodfacts.org.products.small.csv.zip en.openfoodfacts.org.products.small.csv
