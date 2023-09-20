# syntax=docker/dockerfile:1.2
# Base user uid / gid keep 1000 on prod, align with your user on dev
ARG USER_UID=1000
ARG USER_GID=1000
# options for cpan installs
ARG CPANMOPTS=

FROM debian:stretch as stretchy
ADD sources.list /etc/apt/sources.list

FROM stretchy AS hacky

ARG ZXING_VERSION=2.1.0

# Add prerequisites for Imager::zxing
RUN set -x && \
    apt update && \
    apt install -y \
        debian-archive-keyring && \
    apt install -y \
        cpanminus \
        build-essential \
        cmake \
        pkg-config \
        g++ \
        gcc \
        libde265-dev \
        libjpeg-dev \
        libpng-dev \
        libwebp-dev \
        libx265-dev

# Add files to make this a Frankenstein image: Mostly from buster or buster-backports
ADD http://security.debian.org/debian-security/pool/updates/main/g/glibc/libc6_2.28-10+deb10u2_amd64.deb /tmp
ADD http://security.debian.org/debian-security/pool/updates/main/c/curl/libcurl4_7.64.0-4+deb10u6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/r/rhash/librhash0_1.3.8-1_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/libu/libuv1/libuv1_1.24.1-1+deb10u1_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/e/e2fsprogs/libcom-err2_1.44.5-1+deb10u3_amd64.deb /tmp
ADD http://security.debian.org/debian-security/pool/updates/main/k/krb5/libgssapi-krb5-2_1.17-3+deb10u5_amd64.deb /tmp
ADD http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.1_1.1.1n-0+deb10u6_amd64.deb /tmp
ADD http://security.debian.org/debian-security/pool/updates/main/k/krb5/libk5crypto3_1.17-3+deb10u5_amd64.deb /tmp
ADD http://security.debian.org/debian-security/pool/updates/main/k/krb5/libkrb5-3_1.17-3+deb10u5_amd64.deb /tmp
ADD http://security.debian.org/debian-security/pool/updates/main/k/krb5/libkrb5support0_1.17-3+deb10u5_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/c/cmake/cmake-data_3.18.4-2+deb11u1~bpo10+1_all.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/c/cmake/cmake_3.18.4-2+deb11u1~bpo10+1_amd64.deb /tmp
ADD http://security.debian.org/debian-security/pool/updates/main/liba/libarchive/libarchive13_3.3.3-4+deb10u3_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/libz/libzstd/libzstd1_1.3.8+dfsg-3+deb10u2_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-defaults/cpp_8.3.0-1_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/g++-8_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-defaults/gcc_8.3.0-1_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/gcc-8_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-defaults/g++_8.3.0-1_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/cpp-8_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/m/mpclib3/libmpc3_1.1.0-1_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/m/mpfr4/libmpfr6_4.0.2-1_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/i/isl/libisl19_0.20-2_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/gcc-8-base_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libcc1-0_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/b/binutils/binutils_2.31.1-16_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/b/binutils/libbinutils_2.31.1-16_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/b/binutils/binutils-common_2.31.1-16_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/b/binutils/binutils-x86-64-linux-gnu_2.31.1-16_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libgcc-8-dev_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libgcc1_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libgomp1_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libitm1_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libatomic1_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libasan5_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/liblsan0_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libtsan0_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libubsan1_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libmpx2_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libquadmath0_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libstdc++-8-dev_8.3.0-6_amd64.deb /tmp
ADD http://ftp.de.debian.org/debian/pool/main/g/gcc-8/libstdc++6_8.3.0-6_amd64.deb /tmp

# Install the deps
RUN set -x && \
    # The first iteration will install a bunch, but fails,
    dpkg -i --auto-deconfigure /tmp/*.deb ; \
    # so clean up the conflict,
    dpkg -r libcomerr2 ; \
    # and do another run, which will then succeed.
    dpkg -i --auto-deconfigure /tmp/*.deb

# Add zxing-cpp source, and our cmake patch to enable CPack DEB.
ADD https://github.com/zxing-cpp/zxing-cpp/archive/refs/tags/v${ZXING_VERSION}.tar.gz /tmp
ADD zxing.patch /tmp

# Compile zxing-cpp, and a .deb package from that.
RUN set -x && \
    cd /tmp && \
    tar xfz v${ZXING_VERSION}.tar.gz && \
    patch zxing-cpp-${ZXING_VERSION}/zxing.cmake /tmp/zxing.patch && \
    cmake -S zxing-cpp-${ZXING_VERSION} -B zxing-cpp.release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_WRITERS=OFF -DBUILD_READERS=ON -DBUILD_EXAMPLES=OFF && \
    cmake --build zxing-cpp.release -j8 && \
    cd zxing-cpp.release && \
    cpack -G DEB && \
    cd /tmp

# Install the .deb package, and install Imager::* modules to /tmp/local
RUN set -x && \
    dpkg -i /tmp/zxing-cpp-${ZXING_VERSION}/_packages/zxing_${ZXING_VERSION}_amd64.deb && \
    cpanm  --notest --quiet --skip-satisfied --local-lib /tmp/local/ Imager::zxing Imager::File::JPEG Imager::File::PNG Imager::File::WEBP

######################
# Base modperl image stage
######################
FROM stretchy AS modperl
ARG ZXING_VERSION=2.1.0

ADD sources.list /etc/apt/sources.list
# Install cpm to install cpanfile dependencies
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt set -x && \
    apt update && \
    apt install -y \
        apache2 \
        apt-utils \
        cpanminus \
        g++ \
        gcc \
        less \
        libapache2-mod-perl2 \
        # libexpat1-dev \
        make \
        gettext \
        wget \
        imagemagick \
        graphviz \
        tesseract-ocr \
        # perlmagick \
        #
        # Packages from ./cpanfile:
        # If cpanfile specifies a newer version than apt has, cpanm will install the newer version.
        #
        libtie-ixhash-perl \
        libwww-perl \
        libimage-magick-perl \
        libxml-encoding-perl  \
        libtext-unaccent-perl \
        libmime-lite-perl \
        libcache-memcached-fast-perl \
        libjson-pp-perl \
        libclone-perl \
        libcrypt-passwdmd5-perl \
        libencode-detect-perl \
        libgraphics-color-perl \
        libbarcode-zbar-perl \
        libxml-feedpp-perl \
        liburi-find-perl \
        libxml-simple-perl \
        libexperimental-perl \
        libapache2-request-perl \
        libdigest-md5-perl \
        libtime-local-perl \
        libdbd-pg-perl \
        libtemplate-perl \
        liburi-escape-xs-perl \
        # NB: not available in ubuntu 1804 LTS:
#        libmath-random-secure-perl \
        libfile-copy-recursive-perl \
        libemail-stuffer-perl \
        liblist-moreutils-perl \
        libexcel-writer-xlsx-perl \
        libpod-simple-perl \
        liblog-any-perl \
        liblog-log4perl-perl \
        liblog-any-adapter-log4perl-perl \
        # NB: not available in ubuntu 1804 LTS:
#        libgeoip2-perl \
        libemail-valid-perl \
        #
        # cpan dependencies that can be satisfied by apt even if the package itself can't:
        #
        # Action::Retry
        libmath-fibonacci-perl \
        # EV - event loop
        libev-perl \
        # Algorithm::CheckDigits
        libprobe-perl-perl \
        # CLDR::Number
        libmath-round-perl \
        libsoftware-license-perl \
        libtest-differences-perl \
        libtest-exception-perl \
        # Data::Dumper::AutoEncode
        # NB: not available in ubuntu 1804 LTS:
#        libmodule-build-pluggable-perl \
        libclass-accessor-lite-perl \
        # DateTime
        libclass-singleton-perl \
        # DateTime::Locale
        libfile-sharedir-install-perl \
        # Encode::Punycode
        libnet-idn-encode-perl \
        libtest-nowarnings-perl \
        # File::chmod::Recursive
        libfile-chmod-perl \
        # GeoIP2
        libdata-dumper-concise-perl \
        libdata-printer-perl \
        libdata-validate-ip-perl \
        libio-compress-perl \
        libjson-maybexs-perl \
        liblist-allutils-perl \
        liblist-someutils-perl \
        # GraphViz2
        libdata-section-simple-perl \
        libfile-which-perl \
        libipc-run3-perl \
        liblog-handler-perl \
        libtest-deep-perl \
        libwant-perl \
        # Image::OCR::Tesseract
        libfile-find-rule-perl \
        liblinux-usermod-perl \
        # Locale::Maketext::Lexicon::Getcontext
        liblocale-maketext-lexicon-perl \
        # Log::Any::Adapter::TAP
#        liblog-any-adapter-tap-perl \
        # Math::Random::Secure
        libcrypt-random-source-perl \
        libmath-random-isaac-perl \
        libtest-sharedfork-perl \
        libtest-warn-perl \
        # Mojo::Pg
        libsql-abstract-perl \
        # MongoDB
        libauthen-sasl-saslprep-perl \
        libauthen-scram-perl \
#        libbson-perl \
        libclass-xsaccessor-perl \
        libconfig-autoconf-perl \
        libdigest-hmac-perl \
        libpath-tiny-perl \
        libsafe-isa-perl \
        # Spreadsheet::CSV
        libspreadsheet-parseexcel-perl \
        # Test::Number::Delta
        libtest-number-delta-perl \
        libdevel-size-perl \
        gnumeric \
        # for dev
        # gnu readline
        libreadline-dev \
        # IO::AIO needed by Perl::LanguageServer
        libperl-dev \
        # Imager::zxing - build deps
        cmake \
        pkg-config \
        # Imager::zxing - decoders
#        libavif-dev \
        libde265-dev \
#        libheif-dev \
        libjpeg-dev \
        libpng-dev \
        libwebp-dev \
        libx265-dev

# Install custom zxing
COPY --from=hacky /tmp/zxing-cpp-${ZXING_VERSION}/_packages/zxing_${ZXING_VERSION}_amd64.deb /tmp
RUN set -x && \
    dpkg -i /tmp/zxing_2.1.0_amd64.deb && \
    rm /tmp/zxing_2.1.0_amd64.deb

# Run www-data user as host user 'off' or developper uid
ARG USER_UID
ARG USER_GID
RUN usermod --uid $USER_UID www-data && \
    groupmod --gid $USER_GID www-data

######################
# Stage for installing/compiling cpanfile dependencies
######################
FROM modperl AS test
ARG CPANMOPTS
WORKDIR /tmp

# Install Product Opener from the workdir.
COPY ./cpanfile* /tmp/

# Add pre-compiled Perl modules for Imager::zxing
COPY --from=hacky /tmp/local/ /tmp/local/
######################
# Stage for installing/compiling cpanfile dependencies
######################
FROM modperl AS builder
ARG CPANMOPTS
WORKDIR /tmp

# Install Product Opener from the workdir.
COPY ./cpanfile* /tmp/
# Add ProductOpener runtime dependencies from cpan
RUN --mount=type=cache,id=cpanm-cache,target=/root/.cpanm \
    cpanm $CPANMOPTS --notest --quiet --skip-satisfied --local-lib /tmp/local/ --installdeps .

######################
# backend production image stage
######################
FROM modperl AS runnable

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
    for path in data html_data users products product_images orgs new_images logs tmp; do \
        mkdir -p /mnt/podata/${path}; \
    done && \
    chown www-data:www-data -R /mnt/podata && \
    # Create symlinks of data files that are indeed conf data in /mnt/podata (because we currently mix data and conf data)
    # NOTE: do not changes those links for they are in a volume, or handle migration in entry-point
    for path in data-default external-data emb_codes ingredients madenearme packager-codes po taxonomies templates build-cache; do \
        ln -sf /opt/product-opener/${path} /mnt/podata/${path}; \
    done && \
    # Create some necessary files to ensure permissions in volumes
    mkdir -p /opt/product-opener/html/data/ && \
    mkdir -p /opt/product-opener/html/data/taxonomies/ && \
    mkdir -p /opt/product-opener/html/images/ && \
    chown www-data:www-data -R /opt/product-opener/html/ && \
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
FROM runnable as prod
