# SSL Folder for nginx

This folder is populated dynamically when SSL is enabled. Ensure it is empty if you don't have SSL configured as otherwise nginx will throw errors when the frontend container starts.

To enable SSL, use [mkcert](https://github.com/FiloSottile/mkcert) to create `openfoodfacts.localhost` certificates as follows:

```
mkcert openfoodfacts.localhost "*.openfoodfacts.localhost" localhost 127.0.0.1 ::1
```

Copy the resulting `.pem` files to `conf/nginx-docker/ssl`.

Then, create an `ssl.conf` file in `conf/nginx-docker/ssl` with the following contents:

```
listen 443 ssl;
listen [::]:443 ssl;
ssl_certificate ssl/openfoodfacts.localhost+4.pem;
ssl_certificate_key ssl/openfoodfacts.localhost+4-key.pem;
```

Finally, restart the frontend container to load the new settings.

## Sharing the folder with windows

## Renewing the certificate

