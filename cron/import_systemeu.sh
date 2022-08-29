#!/bin/sh

cp -a /home/sftp/systemeu/data/*csv /srv/off/imports/systemeu/data/
cp -a /home/sftp/systemeu/data/*xlsx /srv/off/imports/systemeu/data/

cd /srv/off/imports/systemeu

unzip -j -u -o '/home/sftp/systemeu/data/*zip' -d /srv/off/imports/systemeu/images/

cd /srv/off/imports/systemeu/images

# systemeu zip includes files starting with ._ that are just metadata
mv ._* ../tmp/

# transparent png files support is broken in perlmagick on the production
# server, mogrify them to jpg
mogrify -format jpg *.png
mv *.png ../images.png_converted_to_jpg/


# cd /srv/off/scripts

export PERL5LIB=.

#./convert_systemeu_data_off1.sh

#./import_systemeu_off1.sh

