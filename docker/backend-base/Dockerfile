FROM httpd:latest

# https://github.com/tianon/docker-brew-ubuntu-core/issues/59
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --assume-yes apt-utils

RUN set -x \
    && apt-get install -y --no-install-recommends git ca-certificates libfile-spec-native-perl make gcc libperl-dev g++ \
    libapache2-request-perl \
	libimage-magick-perl \
	libbarcode-zbar-perl \
	tesseract-ocr \
	graphviz \
    imagemagick \
    geoip-database \
    cpanminus \
    && ln -s /usr/share/GeoIP /usr/local/share/GeoIP

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
    && make install \
    && cd .. \
    && rm -r mod_perl-2.0.10

# Prepare Apache to include our custom config
RUN set -x \
    && mkdir -p /usr/local/apache2/conf/sites-enabled \
    && echo 'IncludeOptional conf/sites-enabled/*.conf' >> /usr/local/apache2/conf/httpd.conf

# Remove mod_perl build dependencies
RUN set -x \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
