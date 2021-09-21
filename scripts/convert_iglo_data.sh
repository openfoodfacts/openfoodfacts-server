#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_iglo_data.pl /srv/off/imports/iglo/20190308_Open_Food_Facts_iglo_Master.csv > /srv/off/imports/iglo/iglo_20190308.csv
