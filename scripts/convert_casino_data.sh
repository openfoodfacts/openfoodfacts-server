#!/bin/sh

export PERL5LIB="../lib:${PERL5LIB}"
DEFAULT_MOUNT_PATH=/srv/off
MOUNT_PATH="${1:-$DEFAULT_MOUNT_PATH}"
./convert_casino_data.pl /home/sftp/casino/data/casino_040718_Tableau_des_refs_Co_avec_TVN-1.csv > ${MOUNT_PATH}/import/casino/casino.csv
