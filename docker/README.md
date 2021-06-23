# Product Opener on Docker

This directory contains some experimental files for running Product Opener on [Docker](https://docker.com).

## Docker Compose

### Image from Docker Hub

Just run `docker-compose up` in this directory to run a pre-built image and start the process. This spins up an application container for the backend, an nginx container that acts as a reverse proxy for static files, and a MongoDB container for storage. You can also deploy OFF to Docker Swarm with `docker stack deploy -c docker-compose.yml`.

### Local development

Alternatively, run `docker-compose -f ./docker-compose.yml -f ./docker-compose.dev.yml build backend` once, and then you can run `docker-compose -f docker-compose.yml -f docker-compose.dev.yml up` for local development. This will build a new backend image from your local source files. Note that this binds the docker container to your local develpoment directory, so be sure to build JavaScript etc. by running `npm install && npm run build`, or you will experience missing assets.

Note: You can also build the frontend assets inside docker. See `build_npm.bat` or `build_npm.sh` for more information about this. If you want to use geolocation, you need to update `docker-compose.geolite2.yml` with your [MaxMind Account](https://blog.maxmind.com/2019/12/18/significant-changes-to-accessing-and-using-geolite2-databases/) and license information, and include it in the call to `docker-compose`.

The step by step guide to setup the Product Opener using Docker is available on [dev environment quick start guide](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/installation/dev-environment-quick-start-guide.md).

### Accessing Product Opener

In this Docker image, Product Opener is configured to run on [localhost](http://world.productopener.localhost/). You may need to add this and other subdomains to your `hosts` file (see your operating system's documentation) to access it.

### Connect to MongoDB

If you want to have a look at the running MongoDB database, run `docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec mongodb mongo`.

### Import sample dataset

By default, the container comes without a dataset, because it is intended to be used to run any Product Opener instance in a production cluster. If you require sample data for local development, you can import an extract from [OpenFoodFacts](https://world.openfoodfacts.org) with `docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec backend /opt/scripts/import_sample_data.sh`.

## Kubernetes

The `productopener` directory contains a <a href="https://helm.sh">Helm</a> template, so that you can set up a new ProductOpener instance on <a href="https://kubernetes.io">Kubernetes</a>. Note that the deployments will create a `PersistentVolumeClaim` (PVC) with `ReadWriteMany` access mode, because the nginx container(s) and Apache container(s) will need to access the volume at the same time. This mode is not supported by every storage plugin. See [access modes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes) for more information.
