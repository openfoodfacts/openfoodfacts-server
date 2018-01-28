ARG BRANCH=master
FROM productopener/backend-base

# https://github.com/tianon/docker-brew-ubuntu-core/issues/59
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install --assume-yes apt-utils

ARG BRANCH
ADD https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/${BRANCH}/cpanfile /tmp/cpanfile

WORKDIR "/tmp"

# Add ProductOpener runtime dependencies cpanm
RUN cpanm --quiet --installdeps --notest --skip-satisfied .