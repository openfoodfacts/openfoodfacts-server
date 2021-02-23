#!/bin/sh

# script to process images with cloud vision and to call computer vision
# algorithm
# to be executed through incron:
# incrontab -e -u off
# /srv/off/new_images IN_CREATE /srv/off/scripts/process_new_image_off.sh $@/$#

export PERL5LIB="/srv/off/lib/:${PERL5LIB}"

cd /srv/off/scripts

/srv/off/scripts/run_cloud_vision_ocr.pl $1


