# How to release

## Staging environment

This is automatically done by the CI of github,
see `.github/workflows/container-build.yml`.

The deployment uses docker compose with specific environments variables
and the `docker/prod.yml` overlay.

As soon as you merge a pull request in the `main` branch,
the action is triggered. You can see it at
https://github.com/openfoodfacts/openfoodfacts-server/actions/workflows/container-build.yml

## Production environment

Product Opener is deployed on a container in Proxmox.
The container is a debian server, it must follow the `backend` container version.

In the command lines, I use $SERVICE and $VERSION variables,
corresponding to the service short name (off, opf, etc.) and the version tag.

To deploy you need to execute the following steps:
1. merge the Release Please pull request.
   This will create a new release / version tag on github
1. verify there is no unreleased code on the server:
   ```bash
   sudo -u off bash
   cd /srv/$SERVICE
   git status
   ```
1. update the code:
   ```bash
   sudo -u off bash
   cd /srv/$SERVICE
   git fetch
   git checkout $VERSION
   ```
1. verify every needed symlink is in place
   ```bash
   sudo /srv/$SERVICE/scripts/deploy/verify-deployment.sh $SERVICE
   ```
1. rebuild taxonomies and lang
   ```bash
   sudo -u off bash
   cd /srv/$SERVICE
   source env/setenv.sh $SERVICE
   ./scripts/taxonomies/build_tags_taxonomy.pl
   ./scripts/build_lang.pl
   ```
1. update the frontend assets you just downloaded
   ```bash
   sudo -u off /srv/$SERVICE/scripts/deploy/install-dist-files.sh $VERSION $SERVICE
   ```
1. restart services
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart nginx
   sudo systemctl stop apache2 cloud_vision_ocr@$SERVICE.service minion@$SERVICE.service; \
   sudo systemctl start apache2 cloud_vision_ocr@$SERVICE.service minion@$SERVICE.service
   # On off
   sudo systemctl stop apache2@priority; sudo systemctl start apache2@priority
   ```
