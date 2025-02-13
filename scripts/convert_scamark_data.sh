#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_scamark_data.pl /srv2/off/imports/scamark/FLUX_SCAMARK_OPENFOODFACTS_PRODUIT_000004.xml > /srv2/off/imports/scamark/scamark.csv
