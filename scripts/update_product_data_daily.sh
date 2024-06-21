#!/usr/bin/env bash

cd /srv/off

# Load paths
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

cd /srv/off/scripts
export PERL5LIB="../lib:${PERL5LIB}"

./migrations/2024_06_save_org_product_data_daily.pl
