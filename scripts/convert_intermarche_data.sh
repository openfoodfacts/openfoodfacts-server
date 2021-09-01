#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
DEFAULT_SOURCE_PATH=/srv2/off
DEFAULT_TARGET_PATH=/srv/off
SOURCE_PATH="${1:-$DEFAULT_MOUNT_PATH}"
TARGET_PATH="${2:-$DEFAULT_TARGET_PATH}"
./convert_intermarche_data.pl ${SOURCE_PATH}/imports/artinformatique/data/intermarche/09-07-2019-intermarche.csv > ${TARGET_PATH}/imports/intermarche/intermarche.csv
