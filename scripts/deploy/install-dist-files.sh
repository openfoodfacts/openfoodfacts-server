#!/usr/bin/env bash

# this script is a helper for deployment
# it downloads the assets for a version and extracts them
# It must be followed by install-dist-files.sh which will install files


# fail on error
set -e

if [[ -z "$1" ]]
then
  echo "Usage: $0 <version> [<instance short name>]"
  echo "ex: $0 v2.53.0 off"
  echo "If <instance short name> is not provided, it will be the server name"
  exit 2
fi

VERSION=$1

if [[ -n $2 ]]
then
  SERVICE=$2
else
  SERVICE=$(hostname)
fi

if [[ $(whoami) != off ]]
then
  echo "This script must be run as the off user"
  exit 3
fi

echo "Downloading dist files $VERSION for $SERVICE"
# get archive and untar
curl --fail --location https://github.com/openfoodfacts/openfoodfacts-server/releases/download/$VERSION/frontend-dist.tgz -o /tmp/frontend-dist.tgz
rm -rf /srv/$SERVICE-dist/tmp/$VERSION || true
mkdir -p /srv/$SERVICE-dist/tmp/$VERSION
tar --directory=/srv/$SERVICE-dist/tmp/$VERSION -xzf /tmp/frontend-dist.tgz
# remove old files
rm -rf /srv/$SERVICE-dist/tmp/old || true
mkdir /srv/$SERVICE-dist/tmp/old
# swap current version and old version
shopt -s extglob  # extended globbing
mv /srv/$SERVICE-dist/!(tmp) /srv/$SERVICE-dist/tmp/old
mv /srv/$SERVICE-dist/tmp/$VERSION/* /srv/$SERVICE-dist/
rmdir /srv/$SERVICE-dist/tmp/$VERSION