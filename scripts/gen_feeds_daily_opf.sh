#!/bin/sh

MONGO_URL=10.1.0.102

cd /srv/opf/scripts
./remove_empty_products.pl
./compute_missions.pl
/usr/bin/mongosh $MONGO_URL/opf ./refresh_products_tags.js
./export_database.pl
./mongodb_dump.sh /srv/opf/html openproductsfacts $MONGO_URL opf

cd /srv/opf/html/data
gzip < en.openproductsfacts.org.products.rdf > en.openproductsfacts.org.products.rdf.gz
gzip < fr.openproductsfacts.org.products.rdf > fr.openproductsfacts.org.products.rdf.gz

