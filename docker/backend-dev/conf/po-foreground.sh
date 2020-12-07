#!/bin/sh
mkdir -p /mnt/podata/products /mnt/podata/logs /mnt/podata/users /mnt/podata/po

if [ ! -e /mnt/podata/lang ]
then
  ln -sf /opt/product-opener/lang /mnt/podata/lang
fi

if [ ! -e /mnt/podata/po/common ]
then
  ln -sf /opt/product-opener/po/common /mnt/podata/po/common
fi

if [ ! -e /mnt/podata/po/site-specific ]
then
  ln -sf /opt/product-opener/po/openfoodfacts /mnt/podata/po/site-specific
fi

if [ ! -e /mnt/podata/po/tags ]
then
  ln -sf /opt/product-opener/po/tags /mnt/podata/po/tags
fi

if [ ! -e /mnt/podata/taxonomies ]
then
  ln -sf /opt/product-opener/taxonomies /mnt/podata/taxonomies
fi

if [ ! -e /mnt/podata/ingredients ]
then
  ln -sf /opt/product-opener/ingredients /mnt/podata/ingredients
fi

if [ ! -e /mnt/podata/emb_codes ]
then
  ln -sf /opt/product-opener/emb_codes /mnt/podata/emb_codes
fi

if [ ! -e /mnt/podata/packager-codes ]
then
  ln -sf /opt/product-opener/packager-codes /mnt/podata/packager-codes
fi

if [ ! -e /mnt/podata/ecoscore ]
then
  ln -sf /opt/product-opener/ecoscore /mnt/podata/ecoscore
fi

if [ ! -e /mnt/podata/templates ]
then
  ln -sf /opt/product-opener/templates /mnt/podata/templates
fi

perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl
chown -R www-data:www-data /mnt/podata
chown -R www-data:www-data /opt/product-opener/html/images/products

# https://github.com/docker-library/httpd/blob/75e85910d1d9954ea0709960c61517376fc9b254/2.4/alpine/httpd-foreground
set -e

# Apache gets grumpy about PID files pre-existing
rm -f /usr/local/apache2/logs/httpd.pid

if [ -n "$PERLDB" ]; then
  exec apache2ctl -X -DPERLDB
else
  exec apache2ctl -DFOREGROUND
fi
