FROM hangy/httpd-alpine-perl-modperl AS builder

RUN set -x \
	&& echo -e '@edge http://dl-cdn.alpinelinux.org/alpine/edge/main\n@edgecommunity http://dl-cdn.alpinelinux.org/alpine/edge/community\n@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories \
	&& apk --update --no-cache add \
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


FROM hangy/httpd-alpine-perl-modperl

RUN set -x \
	&& echo -e '@edge http://dl-cdn.alpinelinux.org/alpine/edge/main\n@edgecommunity http://dl-cdn.alpinelinux.org/alpine/edge/community\n@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories \
	&& apk --update --no-cache add \
		imagemagick6 \
		graphviz \
		tesseract-ocr geoip \
		# As of Alpine 3.7, zbar is only available in testing.
		imagemagick@edge \
		zbar@testing \
	&& /etc/periodic/monthly/geoip \
	&& ln -s /usr/share/GeoIP /usr/local/share/GeoIP


# Prepare Apache to include our custom config
RUN set -x \
    && mkdir -p /usr/local/apache2/conf/sites-enabled \
    && echo 'IncludeOptional conf/sites-enabled/*.conf' >> /usr/local/apache2/conf/httpd.conf

# Install Product Opener from the workdir
COPY . /opt/product-opener/
WORKDIR /opt/product-opener

# Copy Perl libraries from the builder image
COPY --from=builder /tmp/local/ /opt/product-opener/local/
