#!/bin/sh

cd /srv/off/imports/fleurymichon/images

php ExportOpenFoodFacts.php

nice ./delete_broken_image_files.pl download/*.png

cp -a /home/sftp/fleurymichon/data/*.xml /srv/off/imports/fleurymichon/data/

cd /srv/off/imports/fleurymichon/data

latest_xml=$(ls -t *.xml | head -n 1)

export PERL5LIB=.

cd /srv/off/scripts

echo $latest_xml

nice ./import_fleurymichon.pl /srv/off/imports/fleurymichon/data/$latest_xml /srv/off/imports/fleurymichon/images/download

