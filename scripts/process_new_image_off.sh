#!/bin/sh

# script to process images with cloud vision and to call computer vision
# algorithm
# to be executed through incron:
# incrontab -e -u off
# /srv/off/new_images IN_CREATE /srv/off/scripts/process_new_image_off.sh $@/$#


if [ -z "$PERL5LIB" ] && [ -f /tmp/env-export.sh ]
then
    # we are in docker and we need all env variables (as incron remove envs for users)
    . /tmp/env-export.sh
fi

export PERL5LIB="/srv/off/lib/:${PERL5LIB}"
DEFAULT_MOUNT_PATH=/srv/off
MOUNT_PATH="${2:-$DEFAULT_MOUNT_PATH}"

${MOUNT_PATH}/scripts/run_cloud_vision_ocr.pl $1


