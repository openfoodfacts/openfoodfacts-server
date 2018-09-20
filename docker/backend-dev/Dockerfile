ARG BRANCH=master
FROM hangy/httpd-alpine-perl-modperl

# Remove APK cache
RUN set -x \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/* \
    && apk update
    
# As of Alpine 3.7, zbar is only available in testing.
RUN echo -e '@edge http://dl-cdn.alpinelinux.org/alpine/edge/main\n@edgecommunity http://dl-cdn.alpinelinux.org/alpine/edge/community\n@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories

# Update alpine package index
RUN apk update

# Prepare Apache to include our custom config
RUN set -x \
    && mkdir -p /usr/local/apache2/conf/sites-enabled \
    && echo 'IncludeOptional conf/sites-enabled/*.conf' >> /usr/local/apache2/conf/httpd.conf

RUN apk add alpine-sdk imagemagick6 imagemagick6-dev graphviz graphviz-dev tesseract-ocr tesseract-ocr-dev geoip \
    && /etc/periodic/monthly/geoip \
    && ln -s /usr/share/GeoIP /usr/local/share/GeoIP

# As of Alpine 3.7, zbar is only available in testing.
RUN apk add imagemagick@edge zbar@testing zbar-dev@testing

# Dependency of libapreq2-2.13, which is not installed automatically.
RUN cpm install ExtUtils::XSBuilder::ParseSource -g

# Builder image stage
ARG BRANCH
ADD https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/${BRANCH}/cpanfile /tmp/cpanfile

WORKDIR "/tmp"

# Add ProductOpener runtime dependencies from the git repositories' cpanfile
RUN cpm install -g

# Install Product Opener from the workdir.
ADD . "/opt/product-opener/"
WORKDIR "/opt/product-opener"

# Add ProductOpener runtime dependencies from the local cpanfile
RUN cpm install -g

# Remove build dependencies
RUN apk del -U alpine-sdk imagemagick6-dev graphviz-dev tesseract-ocr-dev zbar-dev geoip \
    && rm -rf /var/cache/apk/*
