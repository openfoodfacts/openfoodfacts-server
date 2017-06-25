#!/bin/sh

cd /home/off/scripts
./remove_empty_products.pl
./compute_missions.pl
./export_database.pl
./mongodb_dump.sh

cd /home/off/html/data
gzip < en.openfoodfacts.org.products.rdf > en.openfoodfacts.org.products.rdf.gz
gzip < fr.openfoodfacts.org.products.rdf > fr.openfoodfacts.org.products.rdf.gz

