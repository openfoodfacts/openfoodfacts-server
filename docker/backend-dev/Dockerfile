FROM productopener/backend-base-cpan

ADD . "/opt/product-opener/"
WORKDIR "/opt/product-opener"

# Add ProductOpener runtime dependencies from the local cpanfile
RUN cpm install -g

# Remove build dependencies
RUN apk del -U alpine-sdk imagemagick6-dev graphviz-dev tesseract-ocr-dev zbar-dev \
    && rm -rf /var/cache/apk/*
