#!/usr/bin/env bash

if [ -z "$PRODUCT_OPENER_FLAVOR" ] || [ -z "$PRODUCT_OPENER_FLAVOR_SHORT" ]; then
    >&2 echo "Environment variables PRODUCT_OPENER_FLAVOR and PRODUCT_OPENER_FLAVOR_SHORT are required"
    exit 1
fi

# load utils
. error_report_utils.sh

# get pathes
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

if [ -z "$OFF_PUBLIC_DATA_DIR" ]; then
    >&2 echo "Environment variable OFF_PUBLIC_DATA_DIR is required"
    exit 1
fi

# Made near me static pages generation
./scripts/generate_madenearme_page.pl uk en > $OFF_PUBLIC_DATA_DIR/madenearme-uk.html.tmp \
&& mv $OFF_PUBLIC_DATA_DIR/madenearme-uk.html.tmp $OFF_PUBLIC_DATA_DIR/madenearme-uk.html \
|| report_error $? "generate_madenearme_pages.pl.uk.en"

./scripts/generate_madenearme_page.pl world en > $OFF_PUBLIC_DATA_DIR/madenearme.html.tmp \
&& mv $OFF_PUBLIC_DATA_DIR/madenearme.html.tmp $OFF_PUBLIC_DATA_DIR/madenearme.html \
|| report_error $? "generate_madenearme_pages.pl.world.en"

./scripts/generate_madenearme_page.pl fr fr > $OFF_PUBLIC_DATA_DIR/cestemballepresdechezvous.html.tmp \
&& mv $OFF_PUBLIC_DATA_DIR/cestemballepresdechezvous.html.tmp $OFF_PUBLIC_DATA_DIR/cestemballepresdechezvous.html \
|| report_error $? "generate_madenearme_pages.pl.fr.fr"

report_failed_commands $0