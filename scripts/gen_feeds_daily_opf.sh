#!/bin/sh

cd /srv/opf/scripts
./remove_empty_products.pl
./compute_missions.pl
./export_database.pl
./mongodb_dump.sh /srv/opf/html openproductsfacts 10.0.0.2 opf

cd /srv/opf/html/data
gzip < en.openproductsfacts.org.products.rdf > en.openproductsfacts.org.products.rdf.gz
gzip < fr.openproductsfacts.org.products.rdf > fr.openproductsfacts.org.products.rdf.gz

