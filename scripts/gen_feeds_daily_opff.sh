#!/bin/sh

cd /srv/opff/scripts
export PERL5LIB="../lib:${PERL5LIB}"

./remove_empty_products.pl
./gen_top_tags_per_country.pl
./compute_missions.pl
./export_database.pl
./mongodb_dump.sh /srv/opff/html openpetfoodfacts 10.0.0.3 opff

cd /srv/opff/html/data
gzip < en.openpetfoodfacts.org.products.rdf > en.openpetfoodfacts.org.products.rdf.gz
gzip < fr.openpetfoodfacts.org.products.rdf > fr.openpetfoodfacts.org.products.rdf.gz

