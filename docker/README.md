# Product Opener on Docker

This directory contains some experimental files for running Product Opener on [Docker](https://docker.com).

## Docker Compose

### Makefile commands

#### Main commands
* `make dev` build Docker dev environment, binding local code files to the container.
* `make prod` build Docker prod environment, removing most binds.

#### Subcommands
* `make build` builds the NPM frontend assets and the backend container.
  * `make build_npm` builds the NPM frontend assets.
  * `make build_backend` builds the backend container.
* `make load_dev` execute the `import_sample_data.sh` script that loads some data into the MongoDB database.

#### Run commands [dev only]
* `make start` starts the Docker containers.
* `make stop` stops the Docker containers.
* `make restart` restarts the Docker containers.

The step by step guide to setup the Product Opener using Docker is available on [dev environment quick start guide](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/installation/dev-environment-quick-start-guide.md).

### Accessing Product Opener

In this Docker image, Product Opener is configured to run on [localhost](http://world.productopener.localhost/). You may need to add this and other subdomains to your `hosts` file (see your operating system's documentation) to access it:

```
127.0.0.1 world.productopener.localhost fr.productopener.localhost static.productopener.localhost ssl-api.productopener.localhost fr-en.productopener.localhost
```

### Connect to MongoDB

If you want to have a look at the running MongoDB database, run `docker-compose exec mongodb mongo`.

### Import sample dataset

By default, the container comes without a dataset, because it is intended to be used to run any Product Opener instance in a production cluster. If you require sample data for local development, you can import an extract from [OpenFoodFacts](https://world.openfoodfacts.org) with `docker-compose exec backend /opt/scripts/import_sample_data.sh`.

## Kubernetes

The `productopener` directory contains a <a href="https://helm.sh">Helm</a> template, so that you can set up a new ProductOpener instance on <a href="https://kubernetes.io">Kubernetes</a>. Note that the deployments will create a `PersistentVolumeClaim` (PVC) with `ReadWriteMany` access mode, because the nginx container(s) and Apache container(s) will need to access the volume at the same time. This mode is not supported by every storage plugin. See [access modes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes) for more information.
