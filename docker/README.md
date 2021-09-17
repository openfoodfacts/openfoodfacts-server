# Product Opener on Docker

This directory contains `docker-compose` overrides for running Product Opener on [Docker](https://docker.com).
The main docker-compose file [`docker-compose.yml`](../docker-compose.yml) is located in the root of the repository.

The step-by-step guide to setup the Product Opener using Docker is available on [dev environment quick start guide](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/installation/dev-environment-quick-start-guide.md).

## Docker Compose

### Makefile commands

| Command                   | Description                                                                            | Notes                                                         |
| ------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `make dev`                | Setup a fresh dev environment.                                                         | Run only once, then use the `up`, `down`, `restart` commands. |
| `make up`                 | Start containers.                                                                      |                                                               |
| `make down`               | Stop containers and keep the volumes.                                                  | Products and users data will be kept.                         |
| `make hdown`              | Stop containers and delete the volumes (hard down).                                    | Products and users data will be lost !                        |
| `make restart`            | Restart `frontend` and `backend` containers.                                           |                                                               |
| `make reset`              | Run `hdown` and `up`.                                                                  |                                                               |
| `make status`             | Get containers status (up, down, fail).                                                |                                                               |
| `make log`                | Get logs.                                                                              | Include only logs written to container's `stdout`.            |
| `make tail`               | Get other logs (`Apache`, `mod_perl`, ...) bound to the local `logs/` directory.       |                                                               |
| `make prune`              | Save space by removing unused Docker artifacts.                                        | Next build will take time (no cache) !                        |
| `make prune_cache`        | Remove Docker build cache.                                                             | Next build will take time (no build cache) !                  |
| `make clean`              | Clean up your dev environment: removes locally bound folders, run `hdown` and `prune`. | Run `make dev` to recreate a fresh dev env afterwards.        |
| `make import_sample_data` | Load sample data (~100 products) into the MongoDB database.                            |                                                               |
| `make import_prod_data`   | Load latest prod data (~2M products, 1.7GB) into the MongoDB database.                 | Takes up to 10m. Not recommended for dev setups !             |

## Kubernetes

The `productopener` directory contains a <a href="https://helm.sh">Helm</a> template, so that you can set up a new ProductOpener instance on <a href="https://kubernetes.io">Kubernetes</a>. Note that the deployments will create a `PersistentVolumeClaim` (PVC) with `ReadWriteMany` access mode, because the nginx container(s) and Apache container(s) will need to access the volume at the same time. This mode is not supported by every storage plugin. See [access modes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes) for more information.
