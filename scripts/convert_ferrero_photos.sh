#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_ferrero_data.pl /srv/off/imports/ferrero/janvier_2019_photos.csv > /srv/off/imports/ferrero/photos.csv
