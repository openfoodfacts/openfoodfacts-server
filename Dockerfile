# syntax=docker/dockerfile:1.2
# Base user uid / gid keep 1000 on prod, align with your user on dev
ARG USER_UID=1000
ARG USER_GID=1000
# options for cpan installs
ARG CPANMOPTS=

######################
# Base runtime image stage
######################
FROM debian:bullseye-slim AS runtime-base

# Install runtime dependencies only (no build tools, no -dev packages)
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt \
    --mount=type=cache,id=lib-apt-cache,target=/var/lib/apt set -x && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        apache2 \
        apt-utils \
        ca-certificates \
        cpanminus \
        less \
        libapache2-mod-perl2 \
        gettext \
        wget \
        # images processing
        imagemagick \
        graphviz \
        tesseract-ocr \
        # ftp client
        lftp \
        # some compression utils
        gzip \
        tar \
        unzip \
        zip \
        pigz \
        # useful to send mail
        mailutils \
        # Runtime Perl dependencies that cpanm will use newer versions of
        # Keep only those that have runtime library dependencies
        libwww-perl \
        libimage-magick-perl \
        libbarcode-zbar-perl \
        libapache2-request-perl \
        libdbd-pg-perl \
        liburi-escape-xs-perl \
        # Runtime dependencies for cpan modules
        libev-perl \
        libjson-maybexs-perl \
        libcpanel-json-xs-perl \
        libio-compress-perl \
        # Runtime image libraries for Imager::File::* and zxing-cpp
        libwebpmux3 \
        libavif9 \
        libde265-0 \
        libheif1 \
        libjpeg62-turbo \
        libpng16-16 \
        libwebp6 \
        libx265-192 \
        libstdc++6 \
        gnumeric

######################
# Build stage with build tools and -dev packages
######################
FROM runtime-base AS build-base

# Install build tools and development packages needed for compiling Perl modules
RUN set -x && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Build tools
        g++ \
        gcc \
        make \
        cmake \
        pkg-config \
        # Ensure ca-certificates is installed for wget to work
        ca-certificates \
        # Development libraries needed for compiling Perl modules
        libperl-dev \
        libapache2-mod-perl2-dev \
        libssl-dev \
        libreadline-dev \
        # Imager::zxing - build deps
        libavif-dev \
        libde265-dev \
        libheif-dev \
        libjpeg-dev \
        libpng-dev \
        libwebp-dev \
        libx265-dev \
        # Additional Perl packages needed as build or runtime dependencies for cpan modules
        libfile-slurp-perl \
        libtie-ixhash-perl \
        libxml-encoding-perl \
        libtext-unaccent-perl \
        libmime-lite-perl \
        libcache-memcached-fast-perl \
        libjson-pp-perl \
        libclone-perl \
        libcrypt-passwdmd5-perl \
        libencode-detect-perl \
        libgraphics-color-perl \
        libxml-feedpp-perl \
        liburi-find-perl \
        libxml-simple-perl \
        libexperimental-perl \
        libdigest-md5-perl \
        libtime-local-perl \
        libtemplate-perl \
        libanyevent-redis-perl \
        libmath-random-secure-perl \
        libfile-copy-recursive-perl \
        libemail-stuffer-perl \
        liblist-moreutils-perl \
        libexcel-writer-xlsx-perl \
        libpod-simple-perl \
        liblog-any-perl \
        liblog-log4perl-perl \
        liblog-any-adapter-log4perl-perl \
        libgeoip2-perl \
        libemail-valid-perl \
        libmath-fibonacci-perl \
        libprobe-perl-perl \
        libmath-round-perl \
        libsoftware-license-perl \
        libtest-differences-perl \
        libtest-exception-perl \
        libmodule-build-pluggable-perl \
        libclass-accessor-lite-perl \
        libclass-singleton-perl \
        libfile-sharedir-install-perl \
        libfile-chmod-perl \
        libdata-dumper-concise-perl \
        libdata-printer-perl \
        libdata-validate-ip-perl \
        liblist-allutils-perl \
        liblist-someutils-perl \
        libdata-section-simple-perl \
        libfile-which-perl \
        libipc-run3-perl \
        liblog-handler-perl \
        libtest-deep-perl \
        libwant-perl \
        libfile-find-rule-perl \
        liblinux-usermod-perl \
        liblocale-maketext-lexicon-perl \
        liblog-any-adapter-tap-perl \
        libcrypt-random-source-perl \
        libmath-random-isaac-perl \
        libtest-sharedfork-perl \
        libtest-warn-perl \
        libsql-abstract-perl \
        libauthen-sasl-saslprep-perl \
        libauthen-scram-perl \
        libbson-perl \
        libclass-xsaccessor-perl \
        libconfig-autoconf-perl \
        libdigest-hmac-perl \
        libpath-tiny-perl \
        libsafe-isa-perl \
        libspreadsheet-parseexcel-perl \
        libtest-number-delta-perl \
        libdevel-size-perl

# Install zxing-cpp from source until 2.1 or higher is available in Debian: https://github.com/openfoodfacts/openfoodfacts-server/pull/8911/files#r1322987464
ARG ZXING_VERSION=2.3.0
RUN set -x && \
    cd /tmp && \
    wget https://github.com/zxing-cpp/zxing-cpp/archive/refs/tags/v${ZXING_VERSION}.tar.gz && \
    tar xfz v${ZXING_VERSION}.tar.gz && \
    cmake -S zxing-cpp-${ZXING_VERSION} -B zxing-cpp.release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_WRITERS=OFF -DBUILD_READERS=ON -DBUILD_EXAMPLES=OFF && \
    cmake --build zxing-cpp.release -j8 && \
    cmake --install zxing-cpp.release && \
    cd / && \
    rm -rf /tmp/v${ZXING_VERSION}.tar.gz /tmp/zxing-cpp*

# Run www-data user AS host user 'off' or developper uid
ARG USER_UID
ARG USER_GID
RUN usermod --uid $USER_UID www-data && \
    groupmod --gid $USER_GID www-data


######################
# Stage for installing/compiling cpanfile dependencies
######################
FROM build-base AS builder
ARG CPANMOPTS
WORKDIR /tmp

# Install Product Opener from the workdir.
COPY ./cpanfile* /tmp/
# Add ProductOpener runtime dependencies from cpan
# we also add apt cache as some libraries might be installed from apt
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt \
    --mount=type=cache,id=lib-apt-cache,target=/var/lib/apt \
    --mount=type=cache,id=cpanm-cache,target=/root/.cpanm \
    set -x && \
    # also run apt update if needed because some package might need to apt install
    ( ( [ ! -e /var/cache/apt/pkgcache.bin ] || [ $(($(date +%s) - $(stat --format=%Y /var/cache/apt/pkgcache.bin))) -gt 3600 ] ) && \
      apt-get update || true \
    ) && \
    # first install some dependencies that are not well handled
    cpanm --notest --quiet --skip-satisfied --local-lib /tmp/local/ "Apache::Bootstrap" && \
    cpanm $CPANMOPTS --notest --quiet --skip-satisfied --local-lib /tmp/local/ --installdeps . \
    # in case of errors show build.log, but still, fail
    || ( for f in /root/.cpanm/work/*/build.log;do echo $f"= start =============";cat $f; echo $f"= end ============="; done; false )

######################
# backend production/runtime image stage
######################
FROM runtime-base AS runnable

# Copy zxing-cpp library from builder
COPY --from=build-base /usr/lib/*zxing* /usr/lib/
COPY --from=build-base /usr/include/ZXing /usr/include/ZXing

# Run www-data user AS host user 'off' or developper uid
ARG USER_UID
ARG USER_GID
RUN usermod --uid $USER_UID www-data && \
    groupmod --gid $USER_GID www-data

# Prepare Apache to include our custom config
RUN rm /etc/apache2/sites-enabled/000-default.conf

# Copy Perl libraries from the builder image
COPY --from=builder /tmp/local/ /opt/perl/local/
ENV PERL5LIB="/opt/product-opener/lib/:/opt/perl/local/lib/perl5/"
ENV PATH="/opt/perl/local/bin:${PATH}"
# Set up apache2 to use npm prefork
RUN \
    a2dismod mpm_event && \
    a2enmod mpm_prefork

# Create writable dirs and change ownership to www-data
RUN \
    mkdir -p var/run/apache2/ && \
    chown www-data:www-data var/run/apache2/ && \
    for path in data html_data users products product_images orgs logs new_images deleted_products_images reverted_products deleted_private_products translate deleted_products deleted.images import_files tmp build-cache/taxonomies debug sftp; do \
        mkdir -p /mnt/podata/${path}; \
    done && \
    chown www-data:www-data -R /mnt/podata && \
    # Create symlinks of data files that are indeed conf data in /mnt/podata (because we currently mix data and conf data)
    # NOTE: do not changes those links for they are in a volume, or handle migration in entry-point
    for path in data-default external-data emb_codes ingredients madenearme packager-codes po taxonomies templates; do \
        ln -sf /opt/product-opener/${path} /mnt/podata/${path}; \
    done && \
    # Create some necessary files to ensure permissions in volumes
    mkdir -p /opt/product-opener/html/data/ && \
    mkdir -p /opt/product-opener/html/data/taxonomies/ && \
    mkdir -p /opt/product-opener/html/images/products && \
    chown www-data:www-data -R /opt/product-opener/html/ && \
    # inter services directories (until we get a real solution)
    for service in obf off opf opff; do \
        mkdir -p /srv/$service; \
        chown www-data:www-data -R /srv/$service; \
    done && \
    # logs dir
    mkdir -p /var/log/apache2/ && \
    chown www-data:www-data -R /var/log
# Install Product Opener from the workdir
COPY --chown=www-data:www-data . /opt/product-opener/

EXPOSE 80
COPY ./docker/docker-entrypoint.sh /
WORKDIR /opt/product-opener/
USER www-data
ENTRYPOINT [ "/docker-entrypoint.sh" ]
# default command is apache2ctl start
CMD ["apache2ctl", "-D", "FOREGROUND"]

######################
# Dev image with additional development tools
######################
FROM build-base AS dev

# Copy zxing-cpp library from builder
COPY --from=build-base /usr/lib/*zxing* /usr/lib/
COPY --from=build-base /usr/include/ZXing /usr/include/ZXing

# Prepare Apache to include our custom config
RUN rm /etc/apache2/sites-enabled/000-default.conf

# Copy Perl libraries from the builder image (including dev tools)
COPY --from=builder /tmp/local/ /opt/perl/local/
ENV PERL5LIB="/opt/product-opener/lib/:/opt/perl/local/lib/perl5/"
ENV PATH="/opt/perl/local/bin:${PATH}"
# Set up apache2 to use npm prefork
RUN \
    a2dismod mpm_event && \
    a2enmod mpm_prefork

# Create writable dirs and change ownership to www-data
RUN \
    mkdir -p var/run/apache2/ && \
    chown www-data:www-data var/run/apache2/ && \
    for path in data html_data users products product_images orgs logs new_images deleted_products_images reverted_products deleted_private_products translate deleted_products deleted.images import_files tmp build-cache/taxonomies debug sftp; do \
        mkdir -p /mnt/podata/${path}; \
    done && \
    chown www-data:www-data -R /mnt/podata && \
    # Create symlinks of data files that are indeed conf data in /mnt/podata (because we currently mix data and conf data)
    # NOTE: do not changes those links for they are in a volume, or handle migration in entry-point
    for path in data-default external-data emb_codes ingredients madenearme packager-codes po taxonomies templates; do \
        ln -sf /opt/product-opener/${path} /mnt/podata/${path}; \
    done && \
    # Create some necessary files to ensure permissions in volumes
    mkdir -p /opt/product-opener/html/data/ && \
    mkdir -p /opt/product-opener/html/data/taxonomies/ && \
    mkdir -p /opt/product-opener/html/images/products && \
    chown www-data:www-data -R /opt/product-opener/html/ && \
    # inter services directories (until we get a real solution)
    for service in obf off opf opff; do \
        mkdir -p /srv/$service; \
        chown www-data:www-data -R /srv/$service; \
    done && \
    # logs dir
    mkdir -p /var/log/apache2/ && \
    chown www-data:www-data -R /var/log
# Install Product Opener from the workdir
COPY --chown=www-data:www-data . /opt/product-opener/

EXPOSE 80
COPY ./docker/docker-entrypoint.sh /
WORKDIR /opt/product-opener/
USER www-data
ENTRYPOINT [ "/docker-entrypoint.sh" ]
# default command is apache2ctl start
CMD ["apache2ctl", "-D", "FOREGROUND"]

######################
# Prod image is default
######################
FROM runnable AS prod
