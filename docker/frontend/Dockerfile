FROM nginx:latest

# https://github.com/tianon/docker-brew-ubuntu-core/issues/59
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --assume-yes apt-utils

RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && git clone --depth 1 https://github.com/openfoodfacts/openfoodfacts-server.git -b master /opt/product-opener

WORKDIR "/opt/product-opener"

# Add ProductOpener runtime dependencies npm and bower
RUN set -x \
    && apt-get install -y --no-install-recommends curl gnupg2 \
    && curl -sL https://deb.nodesource.com/setup_8.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install \
    && node_modules/.bin/bower install --allow-root \