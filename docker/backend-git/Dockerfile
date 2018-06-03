ARG BRANCH=master
FROM productopener/backend-base-cpan

ARG BRANCH
ADD https://api.github.com/repos/openfoodfacts/openfoodfacts-server/compare/${BRANCH}...HEAD /dev/null
RUN git clone --depth 1 https://github.com/openfoodfacts/openfoodfacts-server.git -b ${BRANCH} /opt/product-opener
WORKDIR "/opt/product-opener"

# Add ProductOpener runtime dependencies from the git repositories' cpanfile
RUN cpm install -g

# Remove build dependencies
RUN apk del -U alpine-sdk imagemagick6-dev graphviz-dev tesseract-ocr-dev zbar-dev \
    && rm -rf /var/cache/apk/*
