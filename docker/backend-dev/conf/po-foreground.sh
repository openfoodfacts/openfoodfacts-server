#!/bin/sh
mkdir -p /mnt/podata/products
mkdir -p /mnt/podata/logs
mkdir -p /mnt/podata/users
ln -sf /opt/product-opener/lang /mnt/podata/lang
ln -sf /opt/product-opener/po /mnt/podata/po
ln -sf /opt/product-opener/po/openfoodfacts /opt/product-opener/po/site-specific
ln -sf /opt/product-opener/taxonomies /mnt/podata/taxonomies
ln -sf /opt/product-opener/ingredients /mnt/podata/ingredients
ln -sf /opt/product-opener/emb_codes /mnt/podata/emb_codes
perl -I/opt/product-opener/lib /opt/product-opener/scripts/build_lang.pl
chown -R daemon:daemon /mnt/podata
chown -R daemon:daemon /opt/product-opener/html/images/products
/usr/local/bin/httpd-foreground