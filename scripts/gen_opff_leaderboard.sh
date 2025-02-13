#!/bin/sh

cd /srv/opff/scripts
export PERL5LIB="../lib:${PERL5LIB}"
./gen_opff_leaderboard.pl
