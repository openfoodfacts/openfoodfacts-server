#!/bin/sh

cd /srv/obf/scripts
export PERL5LIB="../lib:${PERL5LIB}"

./remove_empty_products.pl
./gen_top_tags_per_country.pl
./compute_missions.pl
./export_database.pl
./mongodb_dump.sh /srv/obf/html openbeautyfacts 10.1.0.102 obf

cd /srv/obf/html/data
gzip < en.openbeautyfacts.org.products.rdf > en.openbeautyfacts.org.products.rdf.gz
gzip < fr.openbeautyfacts.org.products.rdf > fr.openbeautyfacts.org.products.rdf.gz

