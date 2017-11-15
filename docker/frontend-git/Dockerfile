ARG BRANCH=master
FROM nginx:latest

# https://github.com/tianon/docker-brew-ubuntu-core/issues/59
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --assume-yes apt-utils

RUN set -x \
    && apt-get install -y --no-install-recommends git ca-certificates curl gnupg2 \
    && curl -sL https://deb.nodesource.com/setup_8.x | bash - \
    && apt-get install -y --no-install-recommends nodejs

ARG BRANCH
ADD https://api.github.com/repos/openfoodfacts/openfoodfacts-server/compare/${BRANCH}...HEAD /dev/null
RUN git clone --depth 1 https://github.com/openfoodfacts/openfoodfacts-server.git -b ${BRANCH} /opt/product-opener

WORKDIR "/opt/product-opener"

# Add ProductOpener runtime dependencies npm and bower
RUN set -x \
    && npm install \
    && node_modules/.bin/bower install --allow-root

# Remove build dependencies
RUN set -x \
    && apt-get purge -y --auto-remove git ca-certificates curl gnupg2 nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /opt/product-opener/node_modules