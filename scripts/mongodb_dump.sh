#!/bin/bash

DIR=$1
PREFIX=$2
HOST=$3
DB=$4

echo "DIR $DIR"
echo "PREFIX $PREFIX"
echo "HOST $HOST"
echo "DB $DB"

cd $DIR

mongoexport --collection products --host $HOST --db $DB | gzip > data/$PREFIX-products.jsonl.gz

mongodump --collection products --host $HOST --db $DB
tar cvfz data/$PREFIX-mongodbdump.tar.gz dump
pushd data/ > /dev/null
sha256sum $PREFIX-mongodbdump.tar.gz > sha256sum
md5sum $PREFIX-mongodbdump.tar.gz > md5sum

# Export delta of products modified in the last 24h or since last run of the script
mkdir -p delta
pushd delta/ > /dev/null

TSFILE='last_delta_export.txt'
LASTTS=-1
if [ -f $TSFILE ]; then
  typeset -i LASTTS=$(cat $TSFILE)
else
  LASTTS=$(($(date +%s)-24*60*60))
fi
NEWTS=$(date +%s)
mongoexport --collection products --host $HOST --db $DB --query "{ last_modified_t: { \$gt: $LASTTS, \$lte: $NEWTS } }" | gzip -9 > products_${LASTTS}_${NEWTS}.json.gz

# Delete all but the last 14 delta files - https://stackoverflow.com/a/34862475/11963
ls -tp products_*.json.gz | grep -v '/$' | tail -n +14 | xargs -I {} rm -- {}

echo $NEWTS > $TSFILE
ls -tp products_*.json.gz > index.txt

popd > /dev/null # data/delta
popd > /dev/null # data
