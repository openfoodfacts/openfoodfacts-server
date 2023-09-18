#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_ferrero_data.pl /srv/off/imports/ferrero/janvier_2019_ingredients.csv  /srv/off/imports/ferrero/janvier_2019_nutrition.csv > /srv/off/imports/ferrero/ferrero_janvier_2019.csv
