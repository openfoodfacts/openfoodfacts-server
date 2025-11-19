# syntax=docker/dockerfile:1.2
# Base user uid / gid keep 1000 on prod, align with your user on dev
ARG USER_UID=1000
ARG USER_GID=1000
# Options for cpan installs
ARG CPANMOPTS=
# ZXing library version
ARG ZXING_VERSION=2.3.0

######################
# runtime-base: Minimal runtime dependencies
######################
FROM debian:bullseye-slim AS runtime-base

# BEGIN zxing-cpp 2.x backport. Can be removed after moving to trixie or later.

# Install ca-certificates, so that apt can connect to github pages with HTTPS
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=lib-apt-cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    set -x && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates

# Add backport repo
COPY ./docker/zxing-cpp-backport.gpg /usr/share/keyrings/
COPY ./docker/zxing-cpp-backport.sources /etc/apt/sources.list.d/

# END zxing-cpp 2.x backport. Can be removed after moving to trixie or later.

# Install runtime dependencies only (no build tools, no -dev packages)
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=lib-apt-cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    set -x && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Core runtime
        apache2 \
        apt-utils \
        cpanminus \
        less \
        libapache2-mod-perl2 \
        gettext \
        wget \
        # Image processing (runtime only)
        imagemagick \
        graphviz \
        tesseract-ocr \
        # FTP client
        lftp \
        # Compression utilities
        gzip \
        tar \
        unzip \
        zip \
        pigz \
        # Mail utilities
        mailutils \
        # C libraries for XS modules (not -dev packages)
        libzbar0 \
        libpq5 \
        libev4 \
        # Complex Perl packages that need Debian packaging
        libimage-magick-perl \
        libapache2-request-perl \
        # Runtime-only Perl dependencies not in cpanfile
        libfile-find-rule-perl \
        liblocale-maketext-lexicon-perl \
        # Pure Perl dependencies without C components
        libmath-fibonacci-perl \
        libclass-singleton-perl \
        libtext-unaccent-perl \
        libxml-encoding-perl \
        libxml-simple-perl \
        # Keycloak migration dependencies (#11866)
        libcrypt-passwdmd5-perl

######################
# build-base: Add build tools and -dev packages
######################
FROM runtime-base AS build-base

RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=lib-apt-cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    set -x && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Build tools
        g++ \
        gcc \
        make \
        cmake \
        pkg-config \
        # Development libraries for XS module compilation
        libzbar-dev \
        libapreq2-dev \
        libpq-dev \
        libev-dev \
        # ZXing from backport
        libzxing-dev

######################
# builder: Compile Perl modules from cpanfile
######################
FROM build-base AS builder

ARG CPANMOPTS

WORKDIR /tmp

# Copy cpanfile for dependency installation
COPY cpanfile /tmp/

# Install Perl modules from CPAN
RUN --mount=type=cache,id=cpanm-cache,target=/root/.cpanm \
    set -x && \
    cpanm --notest --quiet --local-lib /tmp/local --installto /tmp/local ${CPANMOPTS} --installdeps .

######################
# runnable: Production runtime (minimal, no build tools)
######################
FROM runtime-base AS runnable

ARG USER_UID
ARG USER_GID

# Copy compiled Perl modules from builder
COPY --from=builder /tmp/local/ /opt/perl/local/

# Copy zxing runtime library from build-base  
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=lib-apt-cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    set -x && \
    apt-get update && \
    apt-get install -y --no-install-recommends libzxing2 && \
    ldconfig

# Set Perl environment
ENV PERL5LIB=/opt/product-opener/lib/:/opt/perl/local/lib/perl5
ENV PATH=/opt/perl/local/bin:${PATH}

# Configure Apache
RUN set -x && \
    a2dismod mpm_event && \
    a2enmod perl && \
    a2enmod rewrite && \
    a2enmod headers && \
    a2enmod env && \
    a2enmod expires && \
    a2enmod deflate && \
    a2enmod proxy && \
    a2enmod proxy_http

RUN set -x && \
    rm /etc/apache2/sites-enabled/* && \
    mkdir -p var/run/apache2/

# Create www-data user with matching UID/GID
RUN set -x && \
    usermod -u ${USER_UID} www-data && \
    groupmod -g ${USER_GID} www-data

COPY docker/docker-entrypoint.sh /

EXPOSE 80

WORKDIR /opt/product-opener

COPY . /opt/product-opener/

USER www-data

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]

######################
# prod: Alias for runnable (default target)
######################
FROM runnable AS prod

######################
# dev: Development image with build tools
######################
FROM build-base AS dev

ARG USER_UID
ARG USER_GID
ARG CPANMOPTS

# Copy compiled Perl modules from builder
COPY --from=builder /tmp/local/ /opt/perl/local/

# Install zxing runtime library
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=lib-apt-cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    set -x && \
    apt-get update && \
    apt-get install -y --no-install-recommends libzxing2 && \
    ldconfig

# Set Perl environment
ENV PERL5LIB=/opt/product-opener/lib/:/opt/perl/local/lib/perl5
ENV PATH=/opt/perl/local/bin:${PATH}

# Configure Apache
RUN set -x && \
    a2dismod mpm_event && \
    a2enmod perl && \
    a2enmod rewrite && \
    a2enmod headers && \
    a2enmod env && \
    a2enmod expires && \
    a2enmod deflate && \
    a2enmod proxy && \
    a2enmod proxy_http

RUN set -x && \
    rm /etc/apache2/sites-enabled/* && \
    mkdir -p var/run/apache2/

# Create www-data user with matching UID/GID
RUN set -x && \
    usermod -u ${USER_UID} www-data && \
    groupmod -g ${USER_GID} www-data

COPY docker/docker-entrypoint.sh /

EXPOSE 80

WORKDIR /opt/product-opener

COPY . /opt/product-opener/

USER www-data

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]
