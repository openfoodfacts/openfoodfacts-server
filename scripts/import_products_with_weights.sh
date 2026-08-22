#!/bin/sh

set -e

cd /tmp

echo "\033[32m------------------ 1/ Retrieve products -----------------\033[0m";
# explicitly specify the wget output file name so that wget does not append .1 if already present
# e.g. if the tar command failed and the script was stopped
wget -O products.tar.gz https://static.openfoodfacts.org/exports/products.packagings-with-weights.tar.gz 2>&1
tar -xzvf products.tar.gz -C /mnt/podata/products
rm products.tar.gz


echo "\033[32m------------------ 3/ Import products -------------------\033[0m";
perl -I/opt/product-opener/lib /opt/product-opener/scripts/update_all_products_from_dir_in_mongodb.pl

echo "\033[32m------------------ 4/ Compute category stats -------------------\033[0m";
perl -I/opt/product-opener/lib /opt/product-opener/scripts/gen_top_tags_per_country.pl
