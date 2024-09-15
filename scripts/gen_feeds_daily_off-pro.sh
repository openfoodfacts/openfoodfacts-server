#!/usr/bin/env bash

cd /srv/off-pro

# Load paths
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

cd /srv/off-pro/scripts

export PERL5LIB="../lib:${PERL5LIB}"

./save_org_product_data_daily_off_pro.pl
