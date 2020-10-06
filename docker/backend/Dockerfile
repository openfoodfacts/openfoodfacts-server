FROM bitnami/minideb:buster AS modperl

# Install cpm to install cpanfile dependencies
RUN set -x \
    && install_packages \
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
    libtest-number-delta-perl

# Stage for installing/compiling cpanfile dependencies
FROM modperl AS builder

WORKDIR /tmp

# Install Product Opener from the workdir.
COPY ./cpanfile /tmp/cpanfile

# Add ProductOpener runtime dependencies from cpan
RUN cpanm --notest --quiet --skip-satisfied --local-lib /tmp/local/ --installdeps .

# Stage for installing/compiling cpanfile dependencies with dev dependencies
FROM builder AS builder-vscode

# Add ProductOpener runtime dependencies from cpan
RUN cpanm --with-develop --notest --quiet --skip-satisfied --local-lib /tmp/local/ --installdeps .

FROM modperl AS runnable

# Prepare Apache to include our custom config
RUN rm /etc/apache2/sites-enabled/000-default.conf

# Copy Perl libraries from the builder image
COPY --from=builder /tmp/local/ /opt/perl/local/
ENV PERL5LIB="/opt/product-opener/lib/:/opt/perl/local/lib/perl5/"
ENV PATH="/opt/perl/local/bin:${PATH}"

EXPOSE 80

FROM runnable AS runnable-vscode
COPY --from=builder-vscode /tmp/local/ /opt/perl/local/

FROM runnable-vscode AS vscode
# This Dockerfile adds a non-root 'vscode' user with sudo access. However, for Linux,
# this user's GID/UID must match your local user UID/GID to avoid permission issues
# with bind mounts. Update USER_UID / USER_GID if yours is not 1000. See
# https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Configure apt and install packages
RUN install_packages apt-utils dialog 2>&1 \
    #
    # Verify git, process tools, lsb-release (common in install instructions for CLIs) installed
    && install_packages git iproute2 procps lsb-release \
    # Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && install_packages sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
    && chmod 0440 /etc/sudoers.d/$USERNAME

FROM runnable-vscode AS perldb

# Readline support for the Perl debugger
RUN install_packages libterm-readline-gnu-perl libterm-readkey-perl

FROM runnable AS withsrc

# Install Product Opener from the workdir
COPY . /opt/product-opener/
WORKDIR /opt/product-opener
