FROM node:12.5.0-alpine as builder

# Install Product Opener from the workdir.
COPY . /opt/product-opener/
WORKDIR /opt/product-opener

# Add ProductOpener runtime dependencies from yarn
RUN yarn install

# Run gulp
RUN yarn run build

FROM nginx:1.17.1-alpine
WORKDIR /opt/product-opener
COPY --from=builder /opt/product-opener/html/ /opt/product-opener/html/
