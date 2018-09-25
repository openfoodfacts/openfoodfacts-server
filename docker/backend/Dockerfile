FROM hangy/httpd-alpine-perl-modperl AS builder

# Remove APK cache
RUN set -x \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*
    
# As of Alpine 3.7, zbar is only available in testing.
RUN echo -e '@edge http://dl-cdn.alpinelinux.org/alpine/edge/main\n@edgecommunity http://dl-cdn.alpinelinux.org/alpine/edge/community\n@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories

# Update alpine package index
RUN apk update

RUN apk add alpine-sdk imagemagick6 imagemagick6-dev graphviz graphviz-dev tesseract-ocr tesseract-ocr-dev geoip \
    && /etc/periodic/monthly/geoip

# As of Alpine 3.7, zbar is only available in testing.
RUN apk add imagemagick@edge zbar@testing zbar-dev@testing

# Dependency of libapreq2-2.13, which is not installed automatically.
RUN cpm install ExtUtils::XSBuilder::ParseSource -g

# Install Product Opener from the workdir.
ADD ./cpanfile /tmp/cpanfile
WORKDIR /tmp

# Add ProductOpener runtime dependencies from cpan
RUN cpm install -g

FROM hangy/httpd-alpine-perl-modperl

# Prepare Apache to include our custom config
RUN set -x \
    && mkdir -p /usr/local/apache2/conf/sites-enabled \
    && echo 'IncludeOptional conf/sites-enabled/*.conf' >> /usr/local/apache2/conf/httpd.conf

# Get GeoIP data
COPY --from=builder /usr/share/GeoIP /usr/share/GeoIP
RUN ln -s /usr/share/GeoIP /usr/local/share/GeoIP

# Copy Perl binaries and libraries from the builder image
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/share/perl5/site_perl/ /usr/local/share/perl5/site_perl/

# Install Product Opener from the workdir
ADD . "/opt/product-opener/"
WORKDIR "/opt/product-opener"
