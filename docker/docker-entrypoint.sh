#!/bin/bash

# Link site-specific translations
ln -sfT /opt/product-opener/po/${PRODUCT_OPENER_FLAVOR} /mnt/podata/po/site-specific

# Link SiteLang.pm
ln -sfT /opt/product-opener/lib/ProductOpener/SiteLang_${PRODUCT_OPENER_FLAVOR_SHORT}.pm /opt/product-opener/lib/ProductOpener/SiteLang.pm

# Link Config.pm and Config2.pm
ln -sfT /opt/product-opener/lib/ProductOpener/Config_${PRODUCT_OPENER_FLAVOR_SHORT}.pm /opt/product-opener/lib/ProductOpener/Config.pm
ln -sfT /opt/product-opener/lib/ProductOpener/Config2_docker.pm /opt/product-opener/lib/ProductOpener/Config2.pm

# 2023-08-16 migration for build-cache… should be in a volume
if [[ -L /mnt/podata/build-cache ]]
then
  unlink /mnt/podata/build-cache
  mkdir -p /mnt/podata/build-cache/taxonomies
fi

# Create symlinks of data files that are indeed conf data in /mnt/podata (because we currently mix data and conf data)
# we need to do this here, because /mnt/podata is a volume
for path in data-default external-data emb_codes ingredients madenearme packager-codes po taxonomies templates;
do
    test -d /mnt/podata/${path} || ln -sf /opt/product-opener/${path} /mnt/podata/${path}
done

# link some static files
for path in data-fields.{md,txt}
do
  test -L /opt/products-opener/html_data/$path || ln -sf /opt/products-opener/html/$path /mnt/podata/html_data/$path
done

# create some directories that might be needed
for path in new_images deleted_products_images reverted_products deleted_private_products translate deleted_products deleted.images import_files tmp build-cache/taxonomies debug
do
  path="/mnt/podata/$path"
  [[ -d $path ]] || mkdir $path
done
for path in dump exports files
do
  src_path=/opt/product-opener/html/data/$path
  target_path=/opt/product-opener/html/$path
  [[ -d $target_path ]] && [[ ! -e $src_path ]] && mv $target_path $src_path
  [[ -d $src_path ]] || mkdir -p $src_path
  [[ -e $target_path ]] && [[ ! -h $target_path ]] && [[ -d $src_path ]] && rm -rf $target_path
  [[ -h $target_path ]] || ln -s $src_path $target_path
done
[[ -d /opt/product-opener/html/data/files/debug ]] || mkdir /opt/product-opener/html/data/files/debug
# exchanges between projects (NOTE: just faking for now)
for service in obf off opf opff
do
  for path in "/srv/$service/products" "/srv/$service/html/images/products"
  do
    [[ -d $path ]] || mkdir -p $path
  done
done


# this is not very elegant, but incron scripts won't have env variables so put them in a file
rm -f /tmp/env-export.sh && export > /tmp/env-export.sh
chown www-data:www-data /tmp/env-export.sh && chmod 0400 /tmp/env-export.sh

# https://github.com/docker-library/httpd/blob/75e85910d1d9954ea0709960c61517376fc9b254/2.4/alpine/httpd-foreground
set -e

# Apache gets grumpy about PID files pre-existing
rm -f /usr/local/apache2/logs/httpd.pid

exec "$@"
