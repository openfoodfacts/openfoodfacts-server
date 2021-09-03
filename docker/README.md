# Product Opener on Docker

This directory contains `docker-compose` overrides for running Product Opener on [Docker](https://docker.com).
The main docker-compose file [`docker-compose.yml`](../docker-compose.yml) is located in the root of the repository.

The step-by-step guide to setup the Product Opener using Docker is available on [dev environment quick start guide](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/installation/dev-environment-quick-start-guide.md).

## Docker Compose

### Makefile commands

* `make dev`: prepare and run Docker dev environment (build NPM assets, build frontend / backend containers, bind code folder).
* `make up`: build the backend container, and start the Docker containers (`docker-compose up -d --build backend`).
* `make down`: stop the Docker containers (`docker-compose down`).
* `make restart`: restart the Docker containers (`docker-compose restart`).
* `make import_sample_data`: execute the `import_sample_data.sh` script that loads some data into the MongoDB database.
* `make log`: get the logs output (`docker-compose logs -f`).
* `make tail`: get the other logs output (local directory bind).
* `make prune`: prune Docker objects that are not needed (save disk space).

## Kubernetes

The `productopener` directory contains a <a href="https://helm.sh">Helm</a> template, so that you can set up a new ProductOpener instance on <a href="https://kubernetes.io">Kubernetes</a>. Note that the deployments will create a `PersistentVolumeClaim` (PVC) with `ReadWriteMany` access mode, because the nginx container(s) and Apache container(s) will need to access the volume at the same time. This mode is not supported by every storage plugin. See [access modes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes) for more information.
