#!/usr/bin/env bash

# check we have the environment variables PRODUCT_OPENER_FLAVOR and PRODUCT_OPENER_FLAVOR_SHORT, otherwise exit

if [ -z "$PRODUCT_OPENER_FLAVOR" ] || [ -z "$PRODUCT_OPENER_FLAVOR_SHORT" ]; then
    >&2 echo "Environment variables PRODUCT_OPENER_FLAVOR and PRODUCT_OPENER_FLAVOR_SHORT are required"
    exit 1
fi

# this script must be launched from server root (e.g. /srv/off)
# check that we have a lib/ProductOpener/Paths.pm file, otherwise exit

if [ ! -f lib/ProductOpener/Paths.pm ]; then
    >&2 echo "lib/ProductOpener/Paths.pm not found. ./scripts/gen_feeds_daily.sh must be launched from server root"
    exit 1
fi

export PERL5LIB=lib:$PERL5LIB

# load paths
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

# load PRODUCT_OPENER_DOMAIN and MONGODB_HOST
. <(perl -e 'use ProductOpener::Config qw/:all/; print "export PRODUCT_OPENER_DOMAIN=$server_domain\nexport MONGODB_HOST=$mongodb_host\n";print("IS_PRO_PLATFORM=1\n") if $server_options{producers_platform};')

# we should now have PRODUCT_OPENER_DOMAIN set (from Config.pm in production mode), check it
if [ -z "$PRODUCT_OPENER_DOMAIN" ]; then
    >&2 echo "Environment variable PRODUCT_OPENER_DOMAIN not set"
    exit 1
fi

cd $OFF_SCRIPTS_DIR

# load utils
. error_report_utils.sh

# off-pro flavor: we don't generate most exports
# but we have some special processing
if [ -n "$IS_PRO_PLATFORM" ]; then
    echo "Generating feeds for off-pro flavor"
    ./save_org_product_data_daily_off_pro.pl || report_error $? "save_org_product_data_daily_off_pro.pl"
    echo "Skipping exports for off-pro flavor"
    report_failed_commands $0
fi

# on Sunday, fix non normalized barcodes
if [ "$(date +%u)" = "7" ]
then
    ./fix_non_normalized_codes.pl --skip-sto || report_error $? "fix_non_normalized_codes.pl"
fi

./remove_empty_products.pl || report_error $? "remove_empty_products.pl"
./gen_top_tags_per_country.pl  || report_error $? "gen_top_tags_per_country.pl"

# Generate the CSV and RDF exports
./export_database.pl || report_error $? "export_database.pl"

echo "Compress CSV exports"
cd $OFF_PUBLIC_DATA_DIR
for export in en.$PRODUCT_OPENER_DOMAIN.products.csv fr.$PRODUCT_OPENER_DOMAIN.products.csv en.$PRODUCT_OPENER_DOMAIN.products.rdf fr.$PRODUCT_OPENER_DOMAIN.products.rdf; do
    echo "Compressing ${export} to new.${export}.gz..."
    nice pigz < $export > new.$export.gz
    echo "Moving new.${export}.gz to ${export}.gz"
    mv -f new.$export.gz $export.gz
done

echo "Copying CSV and RDF files to AWS S3 using MinIO client..."
mc cp \
    en.$PRODUCT_OPENER_DOMAIN.products.csv \
    en.$PRODUCT_OPENER_DOMAIN.products.csv.gz \
    en.$PRODUCT_OPENER_DOMAIN.products.rdf \
    fr.$PRODUCT_OPENER_DOMAIN.products.csv \
    fr.$PRODUCT_OPENER_DOMAIN.products.csv.gz \
    fr.$PRODUCT_OPENER_DOMAIN.products.rdf \
    s3/$PRODUCT_OPENER_FLAVOR-ds \
    || report_error $? "mc.cp.csv"

# Generate the MongoDB dumps and jsonl export
cd $OFF_SCRIPTS_DIR

./mongodb_dump.sh $OFF_PUBLIC_DATA_DIR $PRODUCT_OPENER_FLAVOR $MONGODB_HOST $PRODUCT_OPENER_FLAVOR_SHORT || report_error $? "mongodb_dump.sh"

# Small products data and images export for Docker dev environments
# for about 1/100000th of the products contained in production.
./export_products_data_and_images.pl --sample-mod 100000,0 \
    --products-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-100000.tar.gz \
    --images-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-100000.images.tar.gz \
    --jsonl-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-100000.jsonl.gz \
    --mongo-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-100000.mongodbdump.gz \
    || report_error $? "export_products_data_and_images.pl.modulo-100000"
# On saturday, export modulo 1000 and 10000 for larger sample
if [ "$(date +%u)" = "6" ]
then
    ./export_products_data_and_images.pl --sample-mod 10000,0 \
        --products-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-10000.tar.gz \
        --images-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-10000.images.tar.gz \
        --jsonl-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-10000.jsonl.gz \
        --mongo-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-10000.mongodbdump.gz \
        || report_error $? "export_products_data_and_images.pl.modulo-10000"
    ./export_products_data_and_images.pl --sample-mod 1000,0 \
        --products-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-1000.tar.gz \
        --images-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-1000.images.tar.gz \
        --jsonl-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-1000.jsonl.gz \
        --mongo-file $OFF_PUBLIC_EXPORTS_DIR/products.random-modulo-1000.mongodbdump.gz \
        || report_error $? "export_products_data_and_images.pl.modulo-1000"
fi

# Generate small CSV dump for the offline mode of the mobile app
# parameters are passed through environment variables

# 2024/11/06: this script has been broken for a year in production, it will be reimplemented
# in the upcoming openfoodfacts-export service

# python3 $OFF_SCRIPTS_DIR/generate_dump_for_offline_apps.py
# cd $OFF_PUBLIC_DATA_DIR/offline
# zip new.en.$PRODUCT_OPENER_DOMAIN.products.small.csv.zip en.$PRODUCT_OPENER_DOMAIN.products.small.csv
# mv new.en.$PRODUCT_OPENER_DOMAIN.products.small.csv.zip en.$PRODUCT_OPENER_DOMAIN.products.small.csv.zip

# Exports for Carrefour
cd $OFF_SCRIPTS_DIR
./export_csv_file.pl --fields code,nutrition_grades_tags --query editors_tags=carrefour --separator ';' > $OFF_PUBLIC_DATA_DIR/exports/carrefour_nutriscore.csv || report_error $? "export_csv_file.pl.carrefour_nutriscore"

./export_csv_file.pl --fields code,nutrition_grades_tags --separator ';' > $OFF_PUBLIC_DATA_DIR/exports/nutriscore.csv  || report_error $? "export_csv_file.pl.nutriscore"

# On OFF and on Sunday, generates madenearme pages
if [ "$PRODUCT_OPENER_FLAVOR" == "off" ] && [ "$(date +%u)" = "7" ]
then
    ./generate_madenearme_pages.sh  || report_error $? "generate_madenearme_pages.sh"
fi

report_failed_commands $0