#!/bin/sh

cd /srv/opf/scripts
export PERL5LIB="../lib:${PERL5LIB}"

./remove_empty_products.pl
./gen_top_tags_per_country.pl
./compute_missions.pl
./export_database.pl
./mongodb_dump.sh /srv/opf/html openproductsfacts 10.0.0.3 opf

cd /srv/opf/html/data
gzip < en.openproductsfacts.org.products.rdf > en.openproductsfacts.org.products.rdf.gz
gzip < fr.openproductsfacts.org.products.rdf > fr.openproductsfacts.org.products.rdf.gz

