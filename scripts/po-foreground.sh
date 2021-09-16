#!/bin/sh

# Create writable dirs and change ownership to www-data
for path in " " users products product_images orgs new_images logs; do
  mkdir -p /mnt/podata/${path}
  chown www-data:www-data /mnt/podata/${path}
done

# Create symlinks of data files to /mnt/podata
for path in ecoscore emb_codes forest-footprint ingredients lang packager-codes po taxonomies templates; do
  if [ ! -e /mnt/podata/${path} ]
  then
    ln -sf /opt/product-opener/${path} /mnt/podata/${path}
  fi
done

# Run build_lang.pl
perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl

# https://github.com/docker-library/httpd/blob/75e85910d1d9954ea0709960c61517376fc9b254/2.4/alpine/httpd-foreground
set -e

# Apache gets grumpy about PID files pre-existing
rm -f /usr/local/apache2/logs/httpd.pid

if [ -n "$PERLDB" ]; then
  exec apache2ctl -X -DPERLDB
else
  exec apache2ctl -DFOREGROUND
fi
