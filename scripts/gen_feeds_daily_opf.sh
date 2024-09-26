#!/bin/sh

cd /srv/opf/scripts
export PERL5LIB="../lib:${PERL5LIB}"

./remove_empty_products.pl
./gen_top_tags_per_country.pl
./compute_missions.pl
./export_database.pl

cd /srv/opf/html/data
gzip < en.openproductsfacts.org.products.rdf > en.openproductsfacts.org.products.rdf.gz
gzip < fr.openproductsfacts.org.products.rdf > fr.openproductsfacts.org.products.rdf.gz

cd /srv/opf/scripts
./mongodb_dump.sh /srv/opf/html openproductsfacts 10.1.0.102 opf

