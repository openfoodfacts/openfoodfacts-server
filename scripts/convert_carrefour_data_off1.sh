#!/bin/sh
DEFAULT_MOUNT_PATH=/srv/off
MOUNT_PATH="${1:-$DEFAULT_MOUNT_PATH}"
./convert_carrefour_data.pl ${MOUNT_PATH}/imports/carrefour/data ${MOUNT_PATH}/imports/carrefour/Nomenclature_OpenFoodFacts.csv > ${MOUNT_PATH}/imports/carrefour/carrefour.csv
