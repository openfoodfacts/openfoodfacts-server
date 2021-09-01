#!/bin/sh

set -e

cd /tmp

if [ -d "/mnt/podata/products/390" ]
then
    echo "Products already imported."
else
    echo "\033[32m------------------ 1/ Retrieve products -----------------\033[0m";
    wget https://static.openfoodfacts.org/exports/39-.tar.gz 2>&1
    mkdir -p /mnt/podata/products
    tar -xzvf 39-.tar.gz -C /mnt/podata/products
    chown -R www-data:www-data /mnt/podata/products
    rm 39-.tar.gz

fi

if [ -d "/opt/product-opener/html/images/products/390" ]
then
    echo "Product images already imported"
    exit 0
else
    echo "\033[32m------------------ 2/ Retrieve images -------------------\033[0m";
    wget https://static.openfoodfacts.org/exports/39-.images.tar.gz 2>&1
    mkdir -p /opt/product-opener/html/images/products
    tar -xzvf 39-.images.tar.gz -C /opt/product-opener/html/images/products
    rm 39-.images.tar.gz
fi

echo "\033[32m------------------ 3/ Import products -------------------\033[0m";
perl -I/opt/product-opener/lib /opt/product-opener/scripts/update_all_products_from_dir_in_mongodb.pl
