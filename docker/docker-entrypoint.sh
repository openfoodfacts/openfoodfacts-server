#!/bin/sh

# Create writable dirs and change ownership to www-data
for path in " " users products product_images orgs new_images logs; do
  mkdir -p /mnt/podata/${path}
  chown www-data:www-data /mnt/podata/${path}
done

# Create symlinks of data files to /mnt/podata
for path in ecoscore emb_codes forest-footprint ingredients lang packager-codes po taxonomies templates; do
  ln -sfT /opt/product-opener/${path} /mnt/podata/${path}
done

# Link site-specific translations
ln -sfT /opt/product-opener/po/${PRODUCT_OPENER_FLAVOR} /mnt/podata/po/site-specific

# Link Config.pm and Config2.pm
ln -sfT /opt/product-opener/lib/ProductOpener/Config_${PRODUCT_OPENER_FLAVOR_SHORT}.pm /opt/product-opener/lib/ProductOpener/Config.pm
ln -sfT /opt/product-opener/lib/ProductOpener/Config2_docker.pm /opt/product-opener/lib/ProductOpener/Config2.pm

# Link product images
ln -sfT /mnt/podata/product_images /opt/product-opener/html/images/products

# Run build_lang.pl
perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl

# https://github.com/docker-library/httpd/blob/75e85910d1d9954ea0709960c61517376fc9b254/2.4/alpine/httpd-foreground
set -e

# Apache gets grumpy about PID files pre-existing
rm -f /usr/local/apache2/logs/httpd.pid

exec "$@"
