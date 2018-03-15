#!/bin/sh

cd /home/off/html

mongodump --collection products --db off
tar cvfz data/openfoodfacts-mongodbdump.tar.gz dump
pushd data/ > /dev/null
sha256sum openfoodfacts-mongodbdump.tar.gz > sha256sum
md5sum openfoodfacts-mongodbdump.tar.gz > md5sum

# Export delta of products modified in the last 24h or since last run of the script
TSFILE='last_delta_export.txt'
LASTTS=-1
if [ -f $TSFILE ]; then
  typeset -i LASTTS=$(cat $TSFILE)
else
  LASTTS=$(($(date +%s)-24*60*60))
fi

NEWTS=$(date +%s)
mongoexport --collection products --db off --query "{ last_modified_t: { \$gt: $LASTTS, \$lte: $NEWTS } }" | gzip -9 > products_delta.json.gz
echo $NEWTS > $TSFILE

popd > /dev/null
