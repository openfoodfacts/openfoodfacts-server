ARG BRANCH=master
FROM hangy/httpd-alpine-perl-modperl as builder

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

WORKDIR /tmp

# Dependency of libapreq2-2.13, which is not installed automatically.
RUN cpm install ExtUtils::XSBuilder::ParseSource

# Builder image stage
ARG BRANCH
ADD https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/${BRANCH}/cpanfile /tmp/cpanfile-git

# Add ProductOpener runtime dependencies from the git repositories' cpanfile (speeds up builds if stuff up to here has not changed)
RUN cpm install --cpanfile=/tmp/cpanfile-git

# Install cpanfile from the workdir.
ADD ./cpanfile "/tmp/cpanfile-workdir"

# Add ProductOpener runtime dependencies from the local cpanfile
RUN cpm install --cpanfile=/tmp/cpanfile-workdir

FROM hangy/httpd-alpine-perl-modperl

# Remove APK cache
RUN set -x \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*
    
# As of Alpine 3.7, zbar is only available in testing.
RUN echo -e '@edge http://dl-cdn.alpinelinux.org/alpine/edge/main\n@edgecommunity http://dl-cdn.alpinelinux.org/alpine/edge/community\n@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories

# Update alpine package index
RUN apk update

RUN apk add imagemagick6 graphviz tesseract-ocr geoip \
    && /etc/periodic/monthly/geoip \
    && ln -s /usr/share/GeoIP /usr/local/share/GeoIP

# As of Alpine 3.7, zbar is only available in testing.
RUN apk add imagemagick@edge zbar@testing

# Prepare Apache to include our custom config
RUN set -x \
    && mkdir -p /usr/local/apache2/conf/sites-enabled \
    && echo 'IncludeOptional conf/sites-enabled/*.conf' >> /usr/local/apache2/conf/httpd.conf

# Install Product Opener from the workdir
ADD . "/opt/product-opener/"
WORKDIR "/opt/product-opener"

# Copy Perl libraries from the builder image
COPY --from=builder /tmp/local/ /opt/product-opener/local/

# Remove APK cache
RUN set -x \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*
