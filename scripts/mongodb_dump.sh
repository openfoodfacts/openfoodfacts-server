#!/bin/sh

cd /home/off/html
mongodump --collection products --db off
tar cvfz data/openfoodfacts-mongodbdump.tar.gz dump
pushd data/ > /dev/null
sha256sum openfoodfacts-mongodbdump.tar.gz > sha256sum
md5sum openfoodfacts-mongodbdump.tar.gz > md5sum
popd > /dev/null
