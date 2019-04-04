FROM mhart/alpine-node:10 as builder

RUN set -x \
	&& apk --update --no-cache add \
	# optipng-bin
	pkgconfig autoconf automake libtool nasm build-base zlib-dev

# Install Product Opener from the workdir.
COPY . /opt/product-opener/
WORKDIR /opt/product-opener

# Add ProductOpener runtime dependencies from npm
RUN npm install

# Run webpack
RUN npm run build

FROM nginx:mainline-alpine
WORKDIR /opt/product-opener
COPY --from=builder /opt/product-opener/html/ /opt/product-opener/html/
