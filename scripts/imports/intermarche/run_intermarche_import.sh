#!/usr/bin/env bash

# do not continue on failure
set -e

# load utils
. scripts/imports/imports_utils.sh

# this script must be launched from server root (/srv/off-pro)
export PERL5LIB=lib:$PERL5LIB

# load paths
echo "Load paths"
. <(perl -e 'use ProductOpener::Paths qw/:all/; print base_paths_loading_script()')

if [[ -z "$OFF_SFTP_HOME_DIR" ]]
then
    >&2 "OFF_SFTP_HOME_DIR not defined, exiting"
    exit 10
fi

DATA_TMP_DIR=$OFF_CACHE_TMP_DIR/intermarche-data

# Separate image directory as we want to keep images cached for later imports
IMAGES_TMP_DIR=$OFF_CACHE_TMP_DIR/intermarche-images

SUCCESS_FILE_PATH="$OFF_PRIVATE_DATA_DIR/intermarche-import-success"

IMPORT_SINCE=$(import_since $SUCCESS_FILE_PATH)

echo "IMPORT_SINCE: $IMPORT_SINCE days"

# Intermarche prefers that we do not keep already processed files in the sftp
# directory, so we move them to a different place, but still keep past files
# in case we need to reprocess them
echo "Move csv and image files to $OFF_SFTP_HOME_DIR/artinformatique/data/intermarche/"
cp -a $OFF_SFTP_HOME_DIR/artinformatique/data/intermarche/* $OFF_SFTP_HOME_DIR/artinformatique-backup/data/intermarche/

# copy CSV files modified since the last successful run
echo "Copy CSV files modified since the last successful run"
rm -rf $DATA_TMP_DIR
mkdir $DATA_TMP_DIR
mkdir $DATA_TMP_DIR/data

find $OFF_SFTP_HOME_DIR/artinformatique-backup/data/intermarche/ -mtime -$IMPORT_SINCE -type f -name "*.csv*" -exec cp {} $DATA_TMP_DIR/data/ \;

# The CSV files are in a format like 19-11-2023-intermarche.csv and sometimes they
# send us files from multiple months
# In order to import them in the right order, we rename them with YYYY-MM-DD first

for filepath in $DATA_TMP_DIR/data/*.csv; do
    # Check if the file is in the right format
    echo "Renaming $file"
    # Keep only the file name
    file="${filepath##*/}"
    if [[ $file =~ ^[0-9]{2}-[0-9]{2}-[0-9]{4}-intermarche\.csv$ ]]; then
        # Extract the day, month, and year from the filename
        day=${file:0:2}
        month=${file:3:2}
        year=${file:6:4}
        # Construct the new filename
        newfile="${year}-${month}-${day}-intermarche.csv"
        # Rename the file
        mv -- "$filepath" "$DATA_TMP_DIR/data/$newfile"
    else
        echo "File $file, is not in DD-MM-YYYY-intermarche.csv format"
	exit 1
    fi
done

# Copy images
echo $IMAGES_TMP_DIR
mkdir -p $IMAGES_TMP_DIR
find $OFF_SFTP_HOME_DIR/artinformatique-backup/data/intermarche/ -mtime -$IMPORT_SINCE -type f -name "*.jp*" -exec cp {} $IMAGES_TMP_DIR/ \;


# import CSV files in alphabetical order (starting by YYYY-MM-DD)
echo "Import data"
for file in $DATA_TMP_DIR/data/*.csv; do
    # Intermarche files have a BOM at the start of the file, which confuses Text::CSV
    # Remove it if there is one
    sed -i '1s/^\xEF\xBB\xBF//' $file
    echo "Importing $file"
    ./scripts/import_csv_file.pl --csv_file $file --user_id perfqual --comment "Import Perfqual" --source_id "les-mousquetaires" --source_name "Les Mousquetaires" --source_url "https://www.intermarche.com/" --manufacturer --org_id les-mousquetaires --define lc=fr --images_dir $IMAGES_TMP_DIR
done

# mark successful run
mark_successful_run $SUCCESS_FILE_PATH
