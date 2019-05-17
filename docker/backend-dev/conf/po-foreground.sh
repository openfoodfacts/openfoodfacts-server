#!/bin/sh
mkdir -p /mnt/podata/products /mnt/podata/logs /mnt/podata/users
ln -sf /opt/product-opener/lang /mnt/podata/lang
ln -sf /opt/product-opener/po /mnt/podata/po
ln -sf /opt/product-opener/po/openfoodfacts /opt/product-opener/po/site-specific
ln -sf /opt/product-opener/taxonomies /mnt/podata/taxonomies
ln -sf /opt/product-opener/ingredients /mnt/podata/ingredients
ln -sf /opt/product-opener/emb_codes /mnt/podata/emb_codes
perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl
chown -R apache:apache /mnt/podata
chown -R apache:apache /opt/product-opener/html/images/products

# https://github.com/docker-library/httpd/blob/75e85910d1d9954ea0709960c61517376fc9b254/2.4/alpine/httpd-foreground
set -e

# Apache gets grumpy about PID files pre-existing
rm -f /usr/local/apache2/logs/httpd.pid

exec httpd -DFOREGROUND
