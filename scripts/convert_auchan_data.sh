#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_auchan_data.pl /srv/off/imports/auchan/XML-FOOD > /srv/off/imports/auchan/auchan.csv
