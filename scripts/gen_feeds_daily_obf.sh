#!/bin/sh

cd /srv/obf/scripts
./remove_empty_products.pl
./compute_missions.pl
./export_database.pl
./mongodb_dump.sh /srv/obf/html openbeautyfacts 10.0.0.2 obf

cd /srv/obf/html/data
gzip < en.openbeautyfacts.org.products.rdf > en.openbeautyfacts.org.products.rdf.gz
gzip < fr.openbeautyfacts.org.products.rdf > fr.openbeautyfacts.org.products.rdf.gz

