#!/bin/sh
perl -I/opt/product-opener/lib /opt/product-opener/scripts/build_lang.pl
mkdir -p /mnt/podata/products
chown -R daemon:daemon /mnt/podata
/usr/local/bin/httpd-foreground