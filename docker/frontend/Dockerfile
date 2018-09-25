FROM mhart/alpine-node:10 as builder

# Remove APK cache
RUN set -x \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/* \
    && apk update
    
# yarn needs git for retrieving packages and python, make, and so on to build node-sass.
RUN apk add git python2 build-base

# Install Product Opener from the workdir.
ADD . "/opt/product-opener/"
WORKDIR "/opt/product-opener"

# Add ProductOpener runtime dependencies from yarn
RUN yarn install

# Run gulp
RUN yarn run build

FROM nginx:mainline-alpine
WORKDIR "/opt/product-opener"
COPY --from=builder /opt/product-opener/html/ /opt/product-opener/html/
