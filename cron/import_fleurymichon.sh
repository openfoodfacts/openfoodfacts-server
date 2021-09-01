#!/bin/sh

DEFAULT_MOUNT_PATH=/srv/off
MOUNT_PATH="${1:-$DEFAULT_MOUNT_PATH}"

cd ${MOUNT_PATH}/imports/fleurymichon/images

php ExportOpenFoodFacts.php

nice ./delete_broken_image_files.pl download/*.png

cp -a /home/sftp/fleurymichon/data/*.xml ${MOUNT_PATH}/imports/fleurymichon/data/

cd ${MOUNT_PATH}/imports/fleurymichon/data

latest_xml=$(ls -t *.xml | head -n 1)

export PERL5LIB=.

cd ${MOUNT_PATH}/scripts

echo $latest_xml

nice ./import_fleurymichon.pl ${MOUNT_PATH}/imports/fleurymichon/data/$latest_xml ${MOUNT_PATH}/imports/fleurymichon/images/download

