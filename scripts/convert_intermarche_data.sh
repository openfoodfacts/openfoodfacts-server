#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_intermarche_data.pl /srv2/off/imports/artinformatique/data/intermarche/09-07-2019-intermarche.csv > /srv/off/imports/intermarche/intermarche.csv
