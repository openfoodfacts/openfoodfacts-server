# Base stage that adds the Perl runtime and some build utilities to httpd:alpine
FROM httpd:alpine AS perl-runtime

RUN apk -U add --no-cache tzdata git curl wget perl perl-dev openssl openssl-dev make gcc libc-dev zlib-dev \
    && rm -rf /var/cache/apk/*

# Install cpm to install cpanfile dependencies
RUN curl -o- -L --compressed https://git.io/cpm | perl - install App::cpm -g && rm -rf ~/.perl-cpm

# Stage that compiles mod_perl and installs it in the layer
FROM perl-runtime AS modperl
#  Fetch mod_perl source, build and install it
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

# Stage that just adds some runtime packages that will be used in the runnable stage and the builder stage
FROM modperl AS alpinemodperl

RUN set -x \
	  && echo -e '@edge http://dl-cdn.alpinelinux.org/alpine/edge/main\n@edgecommunity http://dl-cdn.alpinelinux.org/alpine/edge/community\n@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories \
	  && apk --update --no-cache add \
    imagemagick6 \
		graphviz \
		tesseract-ocr \
		# As of Alpine 3.7, zbar is only available in testing.
		imagemagick@edge \
		zbar@testing

# Stage for installing/compiling cpanfile dependencies
FROM alpinemodperl AS builder

RUN apk --update --no-cache add \
		alpine-sdk \
		imagemagick6 \
		imagemagick6-dev \
		graphviz \
		graphviz-dev \
		tesseract-ocr \
		tesseract-ocr-dev \
		# As of Alpine 3.7, zbar is only available in testing.
		imagemagick@edge \
		zbar@testing \
		zbar-dev@testing

WORKDIR /tmp

# Dependency of libapreq2-2.13, which is not installed automatically.
RUN cpm install ExtUtils::XSBuilder::ParseSource

# Install Product Opener from the workdir.
COPY ./cpanfile /tmp/cpanfile

# Add ProductOpener runtime dependencies from cpan
RUN cpm install

# Remove some build dependencies that are not required to run the image
RUN apk del --no-cache git curl wget perl-dev openssl-dev make gcc libc-dev zlib-dev

# Helper stage, so that we don't try to install GeoIP upon every rebuild of the source
FROM alpinemodperl AS alpinemodperlgeoip

ADD https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz /tmp/GeoLite2-Country.tar.gz
RUN set -x \
  # Install GeoIP files locally
  && tar xfz /tmp/GeoLite2-Country.tar.gz -C /usr/local/share \
  && rm /tmp/GeoLite2-Country.tar.gz \
  && mv /usr/local/share/GeoLite2-Country_* /usr/local/share/GeoLite2-Country \
  # Prepare Apache to include our custom config
  && mkdir -p /usr/local/apache2/conf/sites-enabled \
  && echo 'IncludeOptional conf/sites-enabled/*.conf' >> /usr/local/apache2/conf/httpd.conf

FROM alpinemodperlgeoip AS runnable

# Copy Perl libraries from the builder image
COPY --from=builder /tmp/local/ /opt/perl/local/

FROM runnable AS withsrc

# Install Product Opener from the workdir
COPY . /opt/product-opener/
WORKDIR /opt/product-opener
