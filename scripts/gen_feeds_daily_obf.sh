#!/bin/sh

cd /srv/obf/scripts
export PERL5LIB="../lib:${PERL5LIB}"

MONGO_URL=10.1.0.102

./remove_empty_products.pl
./compute_missions.pl
/usr/bin/mongosh $MONGO_URL/obf ./refresh_products_tags.js
./export_database.pl
./mongodb_dump.sh /srv/obf/html openbeautyfacts $MONGO_URL obf

cd /srv/obf/html/data
gzip < en.openbeautyfacts.org.products.rdf > en.openbeautyfacts.org.products.rdf.gz
gzip < fr.openbeautyfacts.org.products.rdf > fr.openbeautyfacts.org.products.rdf.gz

