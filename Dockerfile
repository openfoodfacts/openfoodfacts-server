# syntax=docker/dockerfile:1.2
# Base user uid / gid keep 1000 on prod, align with your user on dev
ARG USER_UID=1000
ARG USER_GID=1000
# options for cpan installs
ARG CPANMOPTS=

######################
# Base modperl image stage
######################
FROM debian:bullseye AS modperl

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
        libmath-random-secure-perl \
        libfile-copy-recursive-perl \
        libemail-stuffer-perl \
        liblist-moreutils-perl \
        libexcel-writer-xlsx-perl \
        libpod-simple-perl \
        liblog-any-perl \
        liblog-log4perl-perl \
        liblog-any-adapter-log4perl-perl \
        # NB: not available in ubuntu 1804 LTS:
        libgeoip2-perl \
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
        libmodule-build-pluggable-perl \
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
        liblog-any-adapter-tap-perl \
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
        libbson-perl \
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
        libperl-dev

# Run www-data user as host user 'off' or developper uid
ARG USER_UID
ARG USER_GID
RUN usermod --uid $USER_UID www-data && \
    groupmod --gid $USER_GID www-data


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
