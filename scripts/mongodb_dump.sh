#!/bin/sh

cd /data/off-fr/html
mongodump --collection products --db off-fr
tar cvfz data/openfoodfacts-mongodbdump.tar.gz dump
sha256sum data/openfoodfacts-mongodbdump.tar.gz > data/sha256sum
md5sum data/openfoodfacts-mongodbdump.tar.gz > data/md5sum
