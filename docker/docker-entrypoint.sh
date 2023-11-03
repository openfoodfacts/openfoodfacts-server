#!/bin/bash

# Link site-specific translations
ln -sfT /opt/product-opener/po/${PRODUCT_OPENER_FLAVOR} /mnt/podata/po/site-specific

# Link SiteLang.pm
ln -sfT /opt/product-opener/lib/ProductOpener/SiteLang_${PRODUCT_OPENER_FLAVOR_SHORT}.pm /opt/product-opener/lib/ProductOpener/SiteLang.pm

# Link Config.pm and Config2.pm
ln -sfT /opt/product-opener/lib/ProductOpener/Config_${PRODUCT_OPENER_FLAVOR_SHORT}.pm /opt/product-opener/lib/ProductOpener/Config.pm
ln -sfT /opt/product-opener/lib/ProductOpener/Config2_docker.pm /opt/product-opener/lib/ProductOpener/Config2.pm

# Create symlinks of data files that are indeed conf data in /mnt/podata (because we currently mix data and conf data)
# we need to do this here, because /mnt/podata is a volume
for path in data-default external-data emb_codes ingredients madenearme packager-codes po taxonomies templates build-cache;
do
    test -d /mnt/podata/${path} || ln -sf /opt/product-opener/${path} /mnt/podata/${path}
done

# this is not very elegant, but incron scripts won't have env variables so put them in a file
rm -f /tmp/env-export.sh && export > /tmp/env-export.sh
chown www-data:www-data /tmp/env-export.sh && chmod 0400 /tmp/env-export.sh

# https://github.com/docker-library/httpd/blob/75e85910d1d9954ea0709960c61517376fc9b254/2.4/alpine/httpd-foreground
set -e

# Apache gets grumpy about PID files pre-existing
rm -f /usr/local/apache2/logs/httpd.pid

exec "$@"
