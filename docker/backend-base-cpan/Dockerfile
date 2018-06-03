ARG BRANCH=master
FROM productopener/backend-base

ARG BRANCH
ADD https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/${BRANCH}/cpanfile /tmp/cpanfile

WORKDIR "/tmp"

# Add ProductOpener runtime dependencies from the git repositories' cpanfile
RUN cpm install -g
