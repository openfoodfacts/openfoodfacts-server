#!/bin/bash
set -e

echo "🥫 Initializing Open Food Facts for IDX..."

# Create necessary directories
mkdir -p ~/OFF_DATA/html_data/{dump,exports,files}
mkdir -p ~/OFF_DATA/build-cache/taxonomies-result
mkdir -p ~/OFF_DATA/ingredients
mkdir -p ~/OFF_DATA/off/{products,html}
mkdir -p ~/OFF_DATA/obf/{products,html}
mkdir -p ~/OFF_DATA/opf/{products,html}
mkdir -p ~/OFF_DATA/opff/{products,html}
mkdir -p ~/OFF_DATA/etc

# Create a simple placeholder Config2.pm if it doesn't exist
if [ ! -f ~/OFF_DATA/etc/Config2.pm ]; then
  echo 'package ProductOpener::Config2;
use utf8;
use strict;
use warnings;
1;' > ~/OFF_DATA/etc/Config2.pm
  chmod 644 ~/OFF_DATA/etc/Config2.pm
fi

echo "🥫 IDX initialization complete!"