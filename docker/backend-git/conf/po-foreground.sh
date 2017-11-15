#!/bin/sh
mkdir -p /mnt/podata/products
mkdir -p /mnt/podata/logs
mkdir -p /mnt/podata/users
ln -s /opt/product-opener/lang /mnt/podata/lang
ln -s /opt/product-opener/po /mnt/podata/po
ln -s /opt/product-opener/po/openfoodfacts /opt/product-opener/po/site-specific
ln -s /opt/product-opener/taxonomies /mnt/podata/taxonomies
perl -I/opt/product-opener/lib /opt/product-opener/scripts/build_lang.pl
chown -R daemon:daemon /mnt/podata
chown -R daemon:daemon /opt/product-opener/html/images/products
/usr/local/bin/httpd-foreground