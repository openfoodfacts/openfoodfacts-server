FROM bitnami/minideb:buster AS modperl

# Install cpm to install cpanfile dependencies
RUN set -x \
    && install_packages \
    apache2 \
    apt-utils \
    cpanminus \
    g++ \
    gcc \
    libapache2-mod-perl2 \
    # libexpat1-dev \
    make \
    wget \
    imagemagick \
    graphviz \
    tesseract-ocr \
    # perlmagick \
    # Packages from ./cpanfile
    libwww-perl \
    libimage-magick-perl \
    libxml-encoding-perl  \
    libtext-unaccent-perl \
    libmime-lite-perl \
    libcache-memcached-fast-perl \
    libjson-pp-perl \
    libclone-perl \
    libcrypt-passwdmd5-perl \
    libencode-detect-perl \
    libgraphics-color-perl \
    libbarcode-zbar-perl \
    libxml-feedpp-perl \
    liburi-find-perl \
    libxml-simple-perl \
    libexperimental-perl \
    libapache2-request-perl \
    libdigest-md5-perl \
    libtime-local-perl \
    libdbd-pg-perl

# Stage for installing/compiling cpanfile dependencies
FROM modperl AS builder

WORKDIR /tmp

# Install Product Opener from the workdir.
COPY ./cpanfile /tmp/cpanfile

# Add ProductOpener runtime dependencies from cpan
RUN cpanm --notest --quiet --skip-satisfied --local-lib /tmp/local/ --installdeps .

# Helper stage, so that we don't try to install GeoIP upon every rebuild of the source
FROM modperl AS modperlgeoip

ADD https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz /tmp/GeoLite2-Country.tar.gz
RUN set -x \
  # Install GeoIP files locally
  && tar xfz /tmp/GeoLite2-Country.tar.gz -C /usr/local/share \
  && rm /tmp/GeoLite2-Country.tar.gz \
  && mv /usr/local/share/GeoLite2-Country_* /usr/local/share/GeoLite2-Country \
  # Prepare Apache to include our custom config
  && rm /etc/apache2/sites-enabled/000-default.conf

FROM modperlgeoip AS runnable

# Copy Perl libraries from the builder image
COPY --from=builder /tmp/local/ /opt/perl/local/

EXPOSE 80

FROM runnable AS vscode
# This Dockerfile adds a non-root 'vscode' user with sudo access. However, for Linux,
# this user's GID/UID must match your local user UID/GID to avoid permission issues
# with bind mounts. Update USER_UID / USER_GID if yours is not 1000. See
# https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Configure apt and install packages
RUN install_packages apt-utils dialog 2>&1 \
    #
    # Verify git, process tools, lsb-release (common in install instructions for CLIs) installed
    && install_packages git iproute2 procps lsb-release \
    # Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && install_packages sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
    && chmod 0440 /etc/sudoers.d/$USERNAME

FROM runnable AS withsrc

# Install Product Opener from the workdir
COPY . /opt/product-opener/
WORKDIR /opt/product-opener
