FROM node:26-bookworm

# HTTPS also works on networks that block the Debian mirrors' HTTP traffic.
RUN sed -i 's|http://deb.debian.org|https://deb.debian.org|g' /etc/apt/sources.list.d/debian.sources && \
    printf 'Acquire::http::Timeout "30";\nAcquire::https::Timeout "30";\nAcquire::Retries "3";\n' > /etc/apt/apt.conf.d/80-download-timeout

WORKDIR /opt/product-opener
COPY package.json package-lock.json .npmrc ./
# Component tests do not need the application's dependency lifecycle scripts.
RUN --mount=type=cache,target=/root/.npm npm ci --ignore-scripts
RUN npx --no-install playwright install --with-deps --only-shell chromium

CMD ["npm", "run", "test:browser"]
