#!/bin/sh

cd /srv/off/scripts
export PERL5LIB="../lib:${PERL5LIB}"

#./gen_categories_stats.pl
./gen_users_list.pl

