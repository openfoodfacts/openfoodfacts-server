#!/bin/sh

>&2 echo "FIX this script before running it
- remove php
- load pathes from perl and use them
- eventually use timestamp to determine which file to import
"
exit(1)

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

