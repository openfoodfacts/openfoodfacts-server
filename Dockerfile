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
        # C library dependencies for Perl modules (not the Perl modules themselves)
        # These provide the underlying C libraries needed by CPAN modules
        # Special case: Image::Magick (PerlMagick) has complex build, use Debian package
        libimage-magick-perl \
        # Special case: Apache2::Request has complex Apache integration, use Debian package
        libapache2-request-perl \
        # libzbar - for Barcode::ZBar  
        libzbar0 \
        # libpq - for DBD::Pg
        libpq5 \
        # libev - for EV (not libev-perl which is the Perl binding)
        libev4 \
        # Pure Perl dependencies not in cpanfile but needed at runtime
        libfile-find-rule-perl \
        # Runtime image libraries for Imager::File::* and zxing-cpp
        # needed for  Imager::File::WEBP
        libwebpmux3 \
        # Imager::zxing - decoders
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
# zxing-cpp builder stage - separate to avoid including build in dev image history
######################
FROM debian:bullseye-slim AS zxing-builder

# Install only what's needed to build zxing-cpp
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=lib-apt-cache,target=/var/lib/apt,sharing=locked \
    set -x && \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        g++ \
        gcc \
        make \
        cmake \
        pkg-config \
        ca-certificates \
        curl \
        # zxing-cpp build dependencies
        libavif-dev \
        libde265-dev \
        libheif-dev \
        libjpeg-dev \
        libpng-dev \
        libwebp-dev \
        libx265-dev

# Install zxing-cpp from source until 2.1 or higher is available in Debian: https://github.com/openfoodfacts/openfoodfacts-server/pull/8911/files#r1322987464
ARG ZXING_VERSION=2.3.0
# Note: Using curl with --insecure due to certificate chain issues in some CI environments (GitHub Actions Docker buildx)
# This is safe for downloading from known public repositories. Production deployments should verify certificates work properly.
RUN set -x && \
    cd /tmp && \
    curl --insecure -L -O https://github.com/zxing-cpp/zxing-cpp/archive/refs/tags/v${ZXING_VERSION}.tar.gz && \
    tar xfz v${ZXING_VERSION}.tar.gz && \
    cmake -S zxing-cpp-${ZXING_VERSION} -B zxing-cpp.release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_WRITERS=OFF -DBUILD_READERS=ON -DBUILD_EXAMPLES=OFF && \
    cmake --build zxing-cpp.release -j8 && \
    cmake --install zxing-cpp.release && \
    cd / && \
    rm -rf /tmp/v${ZXING_VERSION}.tar.gz /tmp/zxing-cpp*

######################
# Build stage with build tools and -dev packages
######################
FROM runtime-base AS build-base

# Copy zxing-cpp from builder stage (libraries, headers, and pkgconfig)
# zxing installs to /usr/lib/x86_64-linux-gnu/ so we need to copy from there
COPY --from=zxing-builder /usr/lib/x86_64-linux-gnu/libZXing.so /usr/lib/x86_64-linux-gnu/
COPY --from=zxing-builder /usr/lib/x86_64-linux-gnu/libZXing.so.2.3.0 /usr/lib/x86_64-linux-gnu/
COPY --from=zxing-builder /usr/lib/x86_64-linux-gnu/libZXing.so.2.3 /usr/lib/x86_64-linux-gnu/
COPY --from=zxing-builder /usr/include/ZXing /usr/include/ZXing
# Create pkgconfig directory and copy zxing.pc
RUN mkdir -p /usr/lib/x86_64-linux-gnu/pkgconfig
COPY --from=zxing-builder /usr/lib/x86_64-linux-gnu/pkgconfig/zxing.pc /usr/lib/x86_64-linux-gnu/pkgconfig/
COPY --from=zxing-builder /usr/lib/x86_64-linux-gnu/cmake/ZXing /usr/lib/x86_64-linux-gnu/cmake/ZXing

# Update ldconfig cache so zxing library is found during compilation
RUN ldconfig

# Install build tools and development packages needed for compiling Perl modules
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt \
    --mount=type=cache,id=lib-apt-cache,target=/var/lib/apt \
    set -x && \
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
        # Imager::zxing - build deps (zxing itself built in separate stage)
        libavif-dev \
        libde265-dev \
        libheif-dev \
        libjpeg-dev \
        libpng-dev \
        libwebp-dev \
        libx265-dev \
        # Additional C library -dev packages for Perl XS modules
        # Note: Image::Magick and Apache2::Request use Debian packages due to complex builds
        # libzbar-dev - for Barcode::ZBar
        libzbar-dev \
        # libpq-dev - for DBD::Pg
        libpq-dev \
        # libev-dev - for EV
        libev-dev \
        # Additional Perl packages needed as build or runtime dependencies for cpan modules
        # Only pure dependency packages without CPAN equivalents
        # Additional Perl packages needed as build or runtime dependencies for cpan modules
        # Only pure dependency packages without CPAN equivalents
        libtext-unaccent-perl \
        libcrypt-passwdmd5-perl \
        # Pure dependency packages (not in cpanfile or dependencies of CPAN modules)
        # libmath-fibonacci-perl - dependency for Action::Retry
        libmath-fibonacci-perl \
        # libprobe-perl-perl - dependency for Algorithm::CheckDigits
        libprobe-perl-perl \
        # libmath-round-perl - dependency for CLDR::Number
        libmath-round-perl \
        # libsoftware-license-perl - dependency for CLDR::Number
        libsoftware-license-perl \
        # libtest-differences-perl - dependency for CLDR::Number
        libtest-differences-perl \
        libtest-exception-perl \
        # libmodule-build-pluggable-perl - dependency for Data::Dumper::AutoEncode
        libmodule-build-pluggable-perl \
        # libclass-accessor-lite-perl - dependency for Data::Dumper::AutoEncode
        libclass-accessor-lite-perl \
        # libclass-singleton-perl - dependency for DateTime
        libclass-singleton-perl \
        # libfile-sharedir-install-perl - dependency for DateTime::Locale
        libfile-sharedir-install-perl \
        # libfile-chmod-perl - dependency for File::chmod::Recursive
        libfile-chmod-perl \
        # libdata-dumper-concise-perl - dependency for GeoIP2
        libdata-dumper-concise-perl \
        # libdata-printer-perl - dependency for GeoIP2
        libdata-printer-perl \
        # libdata-validate-ip-perl - dependency for GeoIP2
        libdata-validate-ip-perl \
        liblist-allutils-perl \
        liblist-someutils-perl \
        # libdata-section-simple-perl - dependency for GraphViz2
        libdata-section-simple-perl \
        # libfile-which-perl - dependency for GraphViz2
        libfile-which-perl \
        # libipc-run3-perl - dependency for GraphViz2
        libipc-run3-perl \
        # liblog-handler-perl - dependency for GraphViz2
        liblog-handler-perl \
        # libtest-deep-perl - dependency for GraphViz2
        libtest-deep-perl \
        # libwant-perl - dependency for GraphViz2
        libwant-perl \
        # libfile-find-rule-perl - dependency for Image::OCR::Tesseract
        libfile-find-rule-perl \
        liblinux-usermod-perl \
        # liblocale-maketext-lexicon-perl - dependency for Locale::Maketext::Lexicon::Getcontext
        liblocale-maketext-lexicon-perl \
        liblog-any-adapter-tap-perl \
        # libcrypt-random-source-perl - dependency for Math::Random::Secure
        libcrypt-random-source-perl \
        # libmath-random-isaac-perl - dependency for Math::Random::Secure
        libmath-random-isaac-perl \
        # libtest-sharedfork-perl - dependency for Math::Random::Secure
        libtest-sharedfork-perl \
        # libtest-warn-perl - dependency for Math::Random::Secure
        libtest-warn-perl \
        # libsql-abstract-perl - dependency for Mojo::Pg
        libsql-abstract-perl \
        # libauthen-sasl-saslprep-perl - dependency for MongoDB
        libauthen-sasl-saslprep-perl \
        # libauthen-scram-perl - dependency for MongoDB
        libauthen-scram-perl \
        # libbson-perl - dependency for MongoDB
        libbson-perl \
        # libclass-xsaccessor-perl - dependency for MongoDB
        libclass-xsaccessor-perl \
        # libconfig-autoconf-perl - dependency for MongoDB
        libconfig-autoconf-perl \
        # libdigest-hmac-perl - dependency for MongoDB
        libdigest-hmac-perl \
        # libsafe-isa-perl - dependency for MongoDB
        libsafe-isa-perl \
        # libspreadsheet-parseexcel-perl - dependency for Spreadsheet::CSV
        libspreadsheet-parseexcel-perl \
        libtest-number-delta-perl \
        libdevel-size-perl

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

# Set environment variables to help find zxing library during Perl XS module compilation
ENV PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig \
    LD_LIBRARY_PATH=/usr/lib:/usr/lib/x86_64-linux-gnu

# Update ldconfig cache so zxing and other libraries are found during compilation
RUN ldconfig

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

# Copy zxing-cpp library from zxing-builder stage
# zxing installs to /usr/lib/x86_64-linux-gnu/ so we need to copy from there
COPY --from=zxing-builder /usr/lib/x86_64-linux-gnu/*zxing* /usr/lib/x86_64-linux-gnu/
COPY --from=zxing-builder /usr/lib/x86_64-linux-gnu/*ZXing* /usr/lib/x86_64-linux-gnu/

# Update ldconfig cache so zxing library is found at runtime
RUN ldconfig

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
# NOTE: This stage extends build-base which already has zxing-cpp and build tools
# It adds the compiled Perl modules and application setup
######################
FROM build-base AS dev

# Run www-data user AS host user 'off' or developper uid
ARG USER_UID
ARG USER_GID
RUN usermod --uid $USER_UID www-data && \
    groupmod --gid $USER_GID www-data

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
