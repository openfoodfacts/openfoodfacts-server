#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_yuka_fr_data.pl /srv2/off/imports/biscuiterie-sainte-victoire/biscuiterie-sainte-victoire-yuka-fr.csv > /srv2/off/imports/biscuiterie-sainte-victoire/biscuiterie-sainte-victoire.csv
