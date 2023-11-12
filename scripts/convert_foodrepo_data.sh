#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
./convert_foodrepo_data.pl /data/off/openfood/import2019/openfood-export-v7.csv  > foodrepo.csv
