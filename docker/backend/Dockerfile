FROM httpd:latest

# https://github.com/tianon/docker-brew-ubuntu-core/issues/59
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --assume-yes apt-utils

RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && git clone --depth 1 https://github.com/openfoodfacts/openfoodfacts-server.git -b master /opt/product-opener

WORKDIR "/opt/product-opener"

# Perl from https://github.com/docker-library/httpd/issues/4
# Add mod_perl build dependencies
RUN apt-get install -y libfile-spec-native-perl make gcc libperl-dev g++

#  Fetch mod_perl source, build and install it
#  Note: The fetch URL should be adjusted to point to a local mirror
ADD http://www.eu.apache.org/dist/perl/mod_perl-2.0.10.tar.gz mod_perl-2.0.10.tar.gz
RUN set -x \
    && ln -s /usr/lib/x86_64-linux-gnu/libgdbm.so.3.0.0 /usr/lib/libgdbm.so \
    && tar -zxvf mod_perl-2.0.10.tar.gz \
    && rm mod_perl-2.0.10.tar.gz \
    && cd mod_perl-2.0.10 \
    && perl Makefile.PL MP_AP_PREFIX=/usr/local/apache2 \
    && make \ 
    && make install

# Add ProductOpener runtime dependencies from apt
RUN apt-get install -y --no-install-recommends \
	libapache2-request-perl \
	libimage-magick-perl \
	libbarcode-zbar-perl \
	tesseract-ocr \
	graphviz \
    imagemagick

# Add ProductOpener runtime dependencies cpanm
RUN set -x \
    && apt-get install -y --no-install-recommends cpanminus \
    && cpanm --quiet --installdeps --notest --skip-satisfied .

# Remove mod_perl build dependencies
RUN set -x \
    && rm -r mod_perl-2.0.10  \
    && apt-get purge -y --auto-remove make gcc libperl-dev g++ \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Prepare Apache to include our custom config
RUN set -x \
    && mkdir -p /usr/local/apache2/conf/sites-enabled \
    && echo 'IncludeOptional conf/sites-enabled/*.conf' >> /usr/local/apache2/conf/httpd.conf