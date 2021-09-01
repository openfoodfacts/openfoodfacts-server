#!/bin/sh

DEFAULT_MOUNT_PATH=/srv/off
MOUNT_PATH="${1:-$DEFAULT_MOUNT_PATH}"

cp -a /home/sftp/systemeu/data/*csv ${MOUNT_PATH}/imports/systemeu/data/
cp -a /home/sftp/systemeu/data/*xlsx ${MOUNT_PATH}/imports/systemeu/data/

cd ${MOUNT_PATH}/imports/systemeu

unzip -j -u -o '/home/sftp/systemeu/data/*zip' -d ${MOUNT_PATH}/imports/systemeu/images/

cd ${MOUNT_PATH}/imports/systemeu/images

# systemeu zip includes files starting with ._ that are just metadata
mv ._* ../tmp/

# transparent png files support is broken in perlmagick on the production
# server, mogrify them to jpg
mogrify -format jpg *.png
mv *.png ../images.png_converted_to_jpg/


# cd ${MOUNT_PATH}/scripts

export PERL5LIB=.

#./convert_systemeu_data_off1.sh

#./import_systemeu_off1.sh

