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

mongoexport --collection products --host $HOST --db $DB | gzip > new.$PREFIX-products.jsonl.gz && \
mv new.$PREFIX-products.jsonl.gz $PREFIX-products.jsonl.gz
mongoexport --collection products_obsolete --host $HOST --db $DB | gzip > new.$PREFIX-products_obsolete.jsonl.gz && \
mv new.$PREFIX-products_obsolete.jsonl.gz $PREFIX-products_obsolete.jsonl.gz

mongodump --collection products --host $HOST --db $DB --gzip --archive="new.${PREFIX}-mongodbdump.gz" && \
sha256sum new.$PREFIX-mongodbdump.gz |sed -e 's/new\.//' > new.gz-sha256sum && \
md5sum new.$PREFIX-mongodbdump.gz |sed -e 's/new\.//' > new.gz-md5sum && \
mv new.${PREFIX}-mongodbdump.gz ${PREFIX}-mongodbdump.gz && \
mv new.gz-sha256sum gz-sha256sum && \
mv new.gz-md5sum gz-md5sum

mongodump --collection products_obsolete --host $HOST --db $DB --gzip --archive="new.${PREFIX}_obsolete-mongodbdump.gz" && \
sha256sum new.${PREFIX}_obsolete-mongodbdump.gz |sed -e 's/new\.//' > new.obsolete.gz-sha256sum && \
md5sum new.${PREFIX}_obsolete-mongodbdump.gz |sed -e 's/new\.//' > new.obsolete.gz-md5sum && \
mv new.${PREFIX}_obsolete-mongodbdump.gz ${PREFIX}_obsolete-mongodbdump.gz && \
mv new.obsolete.gz-sha256sum obsolete.gz-sha256sum && \
mv new.obsolete.gz-md5sum obsolete.gz-md5sum

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
mongoexport --collection products --host $HOST --db $DB --query "{ \"last_modified_t\": { \"\$gt\": $LASTTS, \"\$lte\": $NEWTS } }" | gzip -9 > new.${PREFIX}_products_${LASTTS}_${NEWTS}.json.gz && \
mv new.${PREFIX}_products_${LASTTS}_${NEWTS}.json.gz ${PREFIX}_products_${LASTTS}_${NEWTS}.json.gz

# Delete all but the last 14 delta files - https://stackoverflow.com/a/34862475/11963
ls -tp ${PREFIX}_products_*.json.gz | grep -v '/$' | tail -n +14 | xargs -I {} rm -- {}

echo $NEWTS > $TSFILE
ls -tp ${PREFIX}_products_*.json.gz > index.txt

popd > /dev/null # data/delta

# Export recent changes collection
# Export all fields but `ip` (contributor ip address)
mongoexport --collection recent_changes --host $HOST --db $DB --fields=_id,comment,code,userid,rev,countries_tags,t,diffs | gzip -9 > "new.${PREFIX}_recent_changes.jsonl.gz" && \
mv new.${PREFIX}_recent_changes.jsonl.gz ${PREFIX}_recent_changes.jsonl.gz

# Copy files to AWS S3 using MinIO client
mc cp \
    ${PREFIX}-products.jsonl.gz \
    ${PREFIX}_recent_changes.jsonl.gz \
    ${PREFIX}-mongodbdump.gz \
    s3/openfoodfacts-ds
