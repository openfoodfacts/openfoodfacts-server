FROM mhart/alpine-node:10 as builder

RUN set -x \
	&& apk --update --no-cache add \
        # pnpm needs git for retrieving packages and python, make, and so on to build node-sass.
	git \
        python2 \
        build-base \
        curl \
	# optipng-bin
	pkgconfig autoconf automake libtool nasm build-base zlib-dev

RUN curl -L https://unpkg.com/@pnpm/self-installer | node

# pnpm needs git for retrieving packages and python, make, and so on to build node-sass.
RUN apk add git python2 build-base

# Install Product Opener from the workdir.
COPY . /opt/product-opener/
WORKDIR /opt/product-opener

# Add ProductOpener runtime dependencies from pnpm
RUN pnpm install

# Run webpack
RUN pnpm run build

FROM nginx:mainline-alpine
WORKDIR /opt/product-opener
COPY --from=builder /opt/product-opener/html/ /opt/product-opener/html/
