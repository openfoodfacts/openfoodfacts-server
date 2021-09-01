#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
DEFAULT_MOUNT_PATH=/srv/off
MOUNT_PATH="${1:-$DEFAULT_MOUNT_PATH}"
./convert_auchan_data.pl ${MOUNT_PATH}/imports/auchan/XML-FOOD > ${MOUNT_PATH}/imports/auchan/auchan.csv
