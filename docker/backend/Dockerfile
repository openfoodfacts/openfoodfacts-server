# Base stage that adds the Perl runtime and some build utilities to httpd:alpine
FROM alpine AS modperl

RUN set -x \
    && echo -e '@edge http://dl-cdn.alpinelinux.org/alpine/edge/main\n@edgecommunity http://dl-cdn.alpinelinux.org/alpine/edge/community\n@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories \
    && apk -U add --no-cache tzdata git curl wget perl perl-dev openssl openssl-dev make gcc libc-dev zlib-dev apache2-mod-perl@testing \
    && rm -rf /var/cache/apk/*

# Install cpm to install cpanfile dependencies
RUN curl -o- -L --compressed https://git.io/cpm | perl - install App::cpm -g && rm -rf ~/.perl-cpm

# Stage that just adds some runtime packages that will be used in the runnable stage and the builder stage
FROM modperl AS alpinemodperl

RUN set -x \
	  && apk --update --no-cache add \
    imagemagick6 \
		graphviz \
		tesseract-ocr \
    imagemagick \
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
    imagemagick \
		zbar@testing \
		zbar-dev@testing \
    apache2-dev \
    apache2-mod-perl-dev@testing \
    # Add ZBar perl module from git: https://rt.cpan.org/Ticket/Display.html?id=128085
    && wget https://github.com/mchehab/zbar/archive/0.22.2.tar.gz \
    && tar xfz 0.22.2.tar.gz \
    && rm 0.22.2.tar.gz \
    && cd zbar-0.22.2/perl \
    && perl Makefile.PL PREFIX=/tmp/local \
    && make \
    && make install \
    && cd ../.. \
    && rm -rf zbar-0.22.2

WORKDIR /tmp

# Dependency of libapreq2-2.13, which is not installed automatically.
RUN cpm install ExtUtils::XSBuilder::ParseSource

# Install Product Opener from the workdir.
COPY ./cpanfile /tmp/cpanfile

# Add ProductOpener runtime dependencies from cpan
RUN set -x \
  # Remove CPAN zbar perl module from git: https://rt.cpan.org/Ticket/Display.html?id=128085
  && sed -i '/zbar/d' cpanfile \
  && cpm install

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

EXPOSE 80

FROM runnable AS withsrc

# Install Product Opener from the workdir
COPY . /opt/product-opener/
WORKDIR /opt/product-opener
