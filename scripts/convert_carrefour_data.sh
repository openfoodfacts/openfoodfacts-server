#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_carrefour_data.pl /data/off/carrefour/data /data/off/carrefour/Nomenclature_OpenFoodFacts.csv > carrefour.csv
