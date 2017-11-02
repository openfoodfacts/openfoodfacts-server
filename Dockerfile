# Instructions from https://en.wiki.openfoodfacts.org/Infrastructure#New_server_install_log
# And https://en.wiki.openfoodfacts.org/Product_Opener/Installation/Debian_or_Ubuntu

# Debian Jessie
FROM debian:8.1

LABEL maintainer="https://github.com/openfoodfacts/openfoodfacts-server/" \
      description="Open Food Facts database and web interface"

EXPOSE 8080

# To avoid warnings
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends apt-utils

RUN apt-get update -qq && \
    apt-get install -y fail2ban \
                        sudo \
                        build-essential \
                        git

# Add users
RUN useradd -g users -G sudo \
            -d /home/admin -s /bin/bash \
            -p $(echo nimda | openssl passwd -1 -stdin) \
            admin
RUN useradd -g users \
            -d /home/off \
            -s /bin/bash \
            -p $(echo nimda | openssl passwd -1 -stdin) \
            off

# From Installation/Debian_or_Ubuntu wiki
RUN apt-get update -qq && \
    apt-get install -y apache2 build-essential \
                        geoip-bin \
                        geoip-database \
                        imagemagick \
                        libbarcode-zbar-perl \
                        libcache-memcached-fast-perl \
                        libclone-perl \
                        libcrypt-passwdmd5-perl \
                        libdatetime-format-mail-perl \
                        libencode-detect-perl \
                        libgeo-ip-perl \
                        libgraphics-color-perl \
                        libgraphviz-perl \
                        libhtml-defang-perl \
                        libimage-magick-perl \
                        libjson-perl \
                        libmime-lite-perl \
                        libmime-lite-perl \
                        libmongodb-perl \
                        libperl-dev \
                        libtest-nowarnings-perl \
                        libtext-unaccent-perl \
                        liburi-escape-xs-perl \
                        liburi-find-perl \
                        libwww-perl \
                        libxml-encoding-perl \
                        libxml-feedpp-perl \
                        memcached \
                        mongodb \
                        tesseract-ocr \
                        tesseract-ocr-fra zlib1g-dev
# TODO: Remove MongoDB

# From Infrastructure wiki
RUN apt-get update -qq && \
    apt-get install -y exim4 exim4-config

# From Travis
RUN apt-get update -qq && \
    apt-get install -y libapache2-request-perl
                        # libimage-magick-perl && \
                        ## libimage-magick-q16-perl && \
                        # libbarcode-zbar-perl && \
                        # tesseract-ocr && \
                        # graphviz


RUN apt-get update -qq && \
    apt-get install -y libdatetime-perl

# From Infrastructure wiki
# Perl modules
RUN apt-get update -qq && \
    apt-get install -y libwww-perl \
                        libimage-magick-perl \
                        libxml-encoding-perl \
                        libtext-unaccent-perl \
                        libmime-lite-perl \
                        libcache-memcached-fast-perl \
                        libjson-perl \
                        libclone-perl \
                        libgraphviz-perl \
                        libmime-lite-perl \
                        libcrypt-passwdmd5-perl \
                        libencode-detect-perl \
                        libgraphics-color-perl \
                        libbarcode-zbar-perl \
                        libxml-feedpp-perl \
                        libmongodb-perl \
                        liburi-find-perl \
                        libxml-simple-perl

# Perl
RUN apt-get update -qq && \
    apt-get install -y cpanminus

# Node - Frontend
RUN apt-get update -qq && \
    apt-get install -y nodejs npm \
                        libssl-dev

WORKDIR /srv/openfoodfacts

# Install Perl modules
COPY cpanfile /srv/openfoodfacts/
# TODO: Like .travis.yml   -   RUN cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
RUN cpanm --quiet --installdeps --notest --skip-satisfied .
# perl cpanm --installdeps .
# RUN cpan URI::Escape::XS
# && \
#     cpan Encode::Punycode && \
#     cpan GraphViz2 && \
#     cpan HTML::Defang && \
#     cpan Algorithm::CheckDigits && \
#     cpan Geo::IP && \
#     cpan Image::OCR::Tesseract && \
#     cpan DateTime::Format::Mail && \
#     cpan DateTime::Format::CLDR && \
#     cpan DateTime::Locale

# Install Frontend packages
COPY package.json /srv/openfoodfacts/
RUN npm install

# Install Frontend assets
COPY bower.json .bowerrc /srv/openfoodfacts/
# TODO: RUN /srv/openfoodfacts/node_modules/.bin/bower install
RUN node_modules/.bin/bower install
# RUN npm install -g bower
# RUN bower install

COPY . $WORKDIR

# Clena up
RUN mkdir /srv/openfoodfacts/users
RUN mkdir /srv/openfoodfacts/products
RUN chown -R www-data:www-data /srv/openfoodfacts

RUN cd /srv/openfoodfacts/cgi
RUN rm -f Blogs
RUN ln -s . Blogs
RUN ln -s SiteLang_off.pm SiteLang.pm

# Launch
CMD ["/bin/bash", "echo", "It works !"]

# This is perl 5, version 20, subversion 2 (v5.20.2) built for x86_64-linux-gnu-thread-multi

# CMD ["/bin/bash", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]

# branches:
#   except:
#   - l10n_master
# language: perl
# perl:
#   - "system"
# env: COVERAGE=1
# cache:
#   directories:
#   - $HOME/.npm
#   - $HOME/.cache
#   - $HOME/perl5
# addons:
#   apt:
#     packages:
#     - libapache2-request-perl
#     - libimage-magick-perl
#     - libbarcode-zbar-perl
#     - tesseract-ocr
#     - graphviz
# sudo: false
# before_install:
#   - cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
# install:
#   - cpanm --quiet --installdeps --notest --skip-satisfied .
#   - npm install
#   - node_modules/.bin/bower install
#   - ln -s $TRAVIS_BUILD_DIR/lib/ProductOpener/Config_off.pm $TRAVIS_BUILD_DIR/lib/ProductOpener/Config.pm
#   - cp $TRAVIS_BUILD_DIR/lib/ProductOpener/Config2_sample.pm $TRAVIS_BUILD_DIR/lib/ProductOpener/Config2.pm
#   - ln -s $TRAVIS_BUILD_DIR/lib/ProductOpener/SiteLang_off.pm $TRAVIS_BUILD_DIR/lib/ProductOpener/SiteLang.pm
#   - sed -i -e 's|\$server_domain = "openfoodfacts.org";|\$server_domain = "off.travis-ci.org";|g' $TRAVIS_BUILD_DIR/lib/ProductOpener/Config2.pm
#   - sed -i -e 's|\/home\/off|'$TRAVIS_BUILD_DIR'|g' $TRAVIS_BUILD_DIR/lib/ProductOpener/Config2.pm
# script:
#   - prove -l
#   - perl -c -CS -I$TRAVIS_BUILD_DIR/lib lib/startup_apache2.pl
#   - perl -c -CS -I$TRAVIS_BUILD_DIR/lib cgi/product_multilingual.pl
#   - node_modules/.bin/jshint --show-non-errors html/js/product-multilingual.js html/js/search.js
# notifications:
#   slack: openfoodfacts:Pre9ZXKFH1CYtix8DeJAaFi2
