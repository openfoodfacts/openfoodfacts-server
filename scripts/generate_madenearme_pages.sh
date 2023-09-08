#!/usr/bin/env bash

# get pathes
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

# Made near me static pages generation
./scripts/generate_madenearme_page.pl uk en > $OFF_PUBLIC_DATA_DIR/madenearme-uk.html
./scripts/generate_madenearme_page.pl world en > $OFF_PUBLIC_DATA_DIR/madenearme.html
./scripts/generate_madenearme_page.pl fr fr > $OFF_PUBLIC_DATA_DIR/cestemballepresdechezvous.html
