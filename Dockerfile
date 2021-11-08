# Base user uid / gid keep 1000 on prod, align with your user on dev
ARG USER_UID=1000
ARG USER_GID=1000


######################
# Base modperl image stage
######################
FROM bitnami/minideb:buster AS modperl

# Install cpm to install cpanfile dependencies
RUN set -x && \
    install_packages \
        apache2 \
        apt-utils \
        cpanminus \
        g++ \
        gcc \
        less \
        libapache2-mod-perl2 \
        # libexpat1-dev \
        make \
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
        incron

# Run www-data user as host user 'off' or developper uid
ARG USER_UID
ARG USER_GID
RUN usermod --uid $USER_UID www-data && \
    groupmod --gid $USER_GID www-data


######################
# Stage for installing/compiling cpanfile dependencies
######################
FROM modperl AS builder

WORKDIR /tmp

# Install Product Opener from the workdir.
COPY ./cpanfile /tmp/cpanfile

# Add ProductOpener runtime dependencies from cpan
RUN cpanm --notest --quiet --skip-satisfied --local-lib /tmp/local/ --installdeps .


######################
# Stage for installing/compiling cpanfile dependencies with dev dependencies
######################
FROM builder AS builder-vscode

# Add ProductOpener runtime dependencies from cpan
RUN cpanm --with-develop --notest --quiet --skip-satisfied --local-lib /tmp/local/ --installdeps .


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
# Create writable dirs and change ownership to www-data
RUN \
    mkdir -p var/run/apache2/ && \
    chown www-data:www-data var/run/apache2/ && \
    for path in data html_data users products product_images orgs new_images logs tmp; do \
        mkdir -p /mnt/podata/${path}; \
    done && \
    chown www-data:www-data -R /mnt/podata && \
    # Create symlinks of data files in /mnt/podata (because we currently mix data and conf data)
    for path in ecoscore emb_codes forest-footprint ingredients lang packager-codes po taxonomies templates; do \
        ln -sfT /opt/product-opener/${path} /mnt/podata/${path}; \
    done && \
    # Create a symlink for html images
    ln -sfT /mnt/podata/product_images /opt/product-opener/html/images/products

EXPOSE 80
COPY ./docker/docker-entrypoint.sh /
WORKDIR /opt/product-opener/
USER www-data
ENTRYPOINT [ "/docker-entrypoint.sh" ]
# default command is apache2ctl start
CMD ["apache2ctl", "-D", "FOREGROUND"]

######################
# Image for dev
######################
# note: user is not root but you car run --user root in docker if you want
FROM runnable AS vscode
COPY --from=builder-vscode /tmp/local/ /opt/perl/local/
# install usefull packages
USER root
RUN install_packages apt-utils dialog 2>&1 && \
    # Verify git, process tools, lsb-release (common in install instructions for CLIs) installed
    # also add support for readline for debugger etc.
    install_packages \
        git iproute2 procps lsb-release \
        libterm-readline-gnu-perl libterm-readkey-perl
USER www-data

######################
# Prod image is default
######################
FROM runnable as prod
# Install Product Opener from the workdir
COPY --chown=wwww-data:www-data . /opt/product-opener/
