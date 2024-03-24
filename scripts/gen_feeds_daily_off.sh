#!/usr/bin/env bash

cd /srv/off

# load paths
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

cd /srv/off/scripts
export PERL5LIB="../lib:${PERL5LIB}"

./remove_empty_products.pl
./gen_top_tags_per_country.pl
#./compute_missions.pl

# Generate the CSV and RDF exports
./export_database.pl

cd $OFF_PUBLIC_DATA_DIR
for export in en.openfoodfacts.org.products.csv fr.openfoodfacts.org.products.csv en.openfoodfacts.org.products.rdf fr.openfoodfacts.org.products.rdf; do
   nice pigz < $export > new.$export.gz
   mv -f new.$export.gz $export.gz
done

# Generate the MongoDB dumps and jsonl export
cd /srv/off/scripts

./mongodb_dump.sh /srv/off/html openfoodfacts 10.1.0.102 off

# Small products data and images export for Docker dev environments
# for about 1/10000th of the products contained in production.
./export_products_data_and_images.pl --sample-mod 10000,0 --products-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-10000.tar.gz --images-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-10000.images.tar.gz

./generate_dump_for_offline_apps_off.py
cd /srv/off/html/data/offline
zip en.openfoodfacts.org.products.small.csv.zip en.openfoodfacts.org.products.small.csv

# Exports for Carrefour
cd /srv/off
./scripts/export_csv_file.pl --fields code,nutrition_grades_tags --query editors_tags=carrefour --separator ';' > $OFF_PUBLIC_DATA_DIR/exports/carrefour_nutriscore.csv

./scripts/export_csv_file.pl --fields code,nutrition_grades_tags --separator ';' > $OFF_PUBLIC_DATA_DIR/exports/nutriscore.csv

# On sunday, generates madenearme
if [ "$(date +%u)" = "7" ]
then
    ./scripts/generate_madenearme_pages.sh
fi
