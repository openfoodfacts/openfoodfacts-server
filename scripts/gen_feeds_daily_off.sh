#!/bin/sh

cd /srv/off/scripts
./remove_empty_products.pl
#./compute_missions.pl
./export_database.pl
./mongodb_dump.sh /srv/off/html openfoodfacts 10.0.0.2 off

cd /srv/off/html/data
gzip < en.openfoodfacts.org.products.rdf > en.openfoodfacts.org.products.rdf.gz
gzip < fr.openfoodfacts.org.products.rdf > fr.openfoodfacts.org.products.rdf.gz

