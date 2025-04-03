#!/bin/env bash
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

# Copy Config file
cp /opt/product-opener/lib/ProductOpener/Config2_docker.pm ~/OFF_DATA/etc/Config2.pm
chmod 644 ~/OFF_DATA/etc/Config2.pm

echo "🥫 IDX initialization complete!"