#!/bin/sh

MONGO_URL=10.1.0.102

cd /srv/opff/scripts
./remove_empty_products.pl
./compute_missions.pl
/usr/bin/mongosh $MONGO_URL/opff ./refresh_products_tags.js
./export_database.pl
./mongodb_dump.sh /srv/opff/html openpetfoodfacts $MONGO_URL opff

cd /srv/opff/html/data
gzip < en.openpetfoodfacts.org.products.rdf > en.openpetfoodfacts.org.products.rdf.gz
gzip < fr.openpetfoodfacts.org.products.rdf > fr.openpetfoodfacts.org.products.rdf.gz

