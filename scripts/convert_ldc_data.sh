#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_ldc_data.pl BASE_DE_DONNEES_OFF_GROUPE_LDC.csv /data/off/ldc/images > ldc.csv
