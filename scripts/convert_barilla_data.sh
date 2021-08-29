#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_barilla_data.pl /srv2/off/imports/barilla/barilla_20190621.csv > /srv2/off/imports/barilla/barilla_20190621_converted.csv
