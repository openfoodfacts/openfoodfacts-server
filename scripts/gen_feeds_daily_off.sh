#!/bin/sh

cd /srv/off/scripts
export PERL5LIB="../lib:${PERL5LIB}"

./remove_empty_products.pl
./gen_top_tags_per_country.pl
#./compute_missions.pl
./export_database.pl
./mongodb_dump.sh /srv2/off/html openfoodfacts 10.0.0.3 off

cd /srv2/off/html/data
gzip < en.openfoodfacts.org.products.rdf > en.openfoodfacts.org.products.rdf.gz
gzip < fr.openfoodfacts.org.products.rdf > fr.openfoodfacts.org.products.rdf.gz

gzip < en.openfoodfacts.org.products.csv > en.openfoodfacts.org.products.csv.gz
gzip < fr.openfoodfacts.org.products.csv > fr.openfoodfacts.org.products.csv.gz

cd /srv/off/scripts

# Small products data and images export for Docker dev environments
# for about 1/10000th of the products contained in production.
./export_products_data_and_images.pl --sample-mod 10000,0 --products-file /srv/off/html/exports/products.random-modulo-10000.tar.gz --images-file /srv/off/html/exports/products.random-modulo-10000.images.tar.gz

./generate_dump_for_offline_apps_off.py
cd /srv2/off/html/data/offline
zip en.openfoodfacts.org.products.small.csv.zip en.openfoodfacts.org.products.small.csv