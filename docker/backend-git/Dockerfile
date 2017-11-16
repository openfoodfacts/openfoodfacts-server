ARG BRANCH=master
FROM productopener/backend-base-cpan

# https://github.com/tianon/docker-brew-ubuntu-core/issues/59
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --assume-yes apt-utils

ARG BRANCH
ADD https://api.github.com/repos/openfoodfacts/openfoodfacts-server/compare/${BRANCH}...HEAD /dev/null
RUN git clone --depth 1 https://github.com/openfoodfacts/openfoodfacts-server.git -b ${BRANCH} /opt/product-opener
WORKDIR "/opt/product-opener"

# Add ProductOpener runtime dependencies cpanm
RUN cpanm --quiet --installdeps --notest --skip-satisfied .

# Remove build dependencies
RUN set -x \
    && apt-get purge -y --auto-remove make gcc libperl-dev g++ git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
