#!/bin/sh

cd /srv/opff/scripts
./remove_empty_products.pl
./compute_missions.pl
./export_database.pl
./mongodb_dump.sh /srv/opff/html openpetfoodfacts 10.0.0.2 opff

cd /srv/opff/html/data
gzip < en.openpetfoodfacts.org.products.rdf > en.openpetfoodfacts.org.products.rdf.gz
gzip < fr.openpetfoodfacts.org.products.rdf > fr.openpetfoodfacts.org.products.rdf.gz

