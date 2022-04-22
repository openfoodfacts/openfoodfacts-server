#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_saintelucie_data.pl /srv2/off/imports/saintelucie/saintelucie-20190522.csv > /srv2/off/imports/saintelucie/saintelucie.csv
