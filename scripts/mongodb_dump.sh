#!/bin/sh

cd /data/off-fr/html
mongodump --collection products --db off-fr
tar cvfz data/openfoodfacts-mongodbdump.tar.gz dump
