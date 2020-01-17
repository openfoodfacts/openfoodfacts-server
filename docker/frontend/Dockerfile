FROM node:12.13.0-alpine as builder

# Install Product Opener from the workdir.
COPY . /opt/product-opener/
WORKDIR /opt/product-opener

# Add ProductOpener runtime dependencies from npm
RUN npm install

# Run gulp
RUN npm run build

FROM nginx:1.17.5-alpine
WORKDIR /opt/product-opener
COPY --from=builder /opt/product-opener/html/ /opt/product-opener/html/
