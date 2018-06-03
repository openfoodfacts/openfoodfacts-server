FROM hangy/httpd-alpine-perl-modperl

# Prepare Apache to include our custom config
RUN set -x \
    && mkdir -p /usr/local/apache2/conf/sites-enabled \
    && echo 'IncludeOptional conf/sites-enabled/*.conf' >> /usr/local/apache2/conf/httpd.conf

RUN apk add --update alpine-sdk imagemagick6 imagemagick6-dev graphviz graphviz-dev tesseract-ocr tesseract-ocr-dev \
    && rm -rf /var/cache/apk/*

# As of Alpine 3.7, zbar is only available in testing.
RUN echo -e '@edge http://dl-cdn.alpinelinux.org/alpine/edge/main\n@edgecommunity http://dl-cdn.alpinelinux.org/alpine/edge/community\n@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories
RUN apk add -U imagemagick@edge zbar@testing zbar-dev@testing \
    && rm -rf /var/cache/apk/*

# Dependency of libapreq2-2.13, which is not installed automatically.
RUN cpm install ExtUtils::XSBuilder::ParseSource -g
