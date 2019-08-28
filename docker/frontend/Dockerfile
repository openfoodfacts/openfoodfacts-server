FROM node:12.9.0-alpine as builder

# Install Product Opener from the workdir.
COPY . /opt/product-opener/
WORKDIR /opt/product-opener

# Add ProductOpener runtime dependencies from yarn
RUN yarn install

# Run gulp
RUN yarn run build

FROM nginx:1.17.3-alpine
WORKDIR /opt/product-opener
COPY --from=builder /opt/product-opener/html/ /opt/product-opener/html/
