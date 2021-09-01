#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
DEFAULT_MOUNT_PATH=/srv/off
MOUNT_PATH="${1:-$DEFAULT_MOUNT_PATH}"
./convert_ferrero_data.pl ${MOUNT_PATH}/imports/ferrero/janvier_2019_ingredients.csv  ${MOUNT_PATH}/imports/ferrero/janvier_2019_nutrition.csv > ${MOUNT_PATH}/imports/ferrero/ferrero_janvier_2019.csv
