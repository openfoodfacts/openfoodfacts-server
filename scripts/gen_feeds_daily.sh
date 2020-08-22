#!/bin/sh

cd /srv/off/scripts
export PERL5LIB="../lib:${PERL5LIB}"

./remove_empty_products.pl
./compute_missions.pl
./export_database.pl
./mongodb_dump.sh /srv/off/html openfoodfacts 127.0.0.1 off

cd /srv/off/html/data
gzip < en.openfoodfacts.org.products.rdf > en.openfoodfacts.org.products.rdf.gz
gzip < fr.openfoodfacts.org.products.rdf > fr.openfoodfacts.org.products.rdf.gz

