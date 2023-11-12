#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_casino_data.pl /home/sftp/casino/data/casino_040718_Tableau_des_refs_Co_avec_TVN-1.csv > /srv/off/import/casino/casino.csv
