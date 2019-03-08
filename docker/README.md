# Product Opener on Docker

This directory contains some experimental files for running Product Opener on [Docker](https://docker.com).

## Docker Compose

Just run `docker-compose up` in this directory to build backend image and start the process. This spins up an application container for the backend, an nginx container that acts as a reverse proxy for static files, and a MongoDB container for storage. Note that this binds the docker container to your local develpoment directory, so be sure to build JavaScript etc. by running `yarn install && yarn run build`, or you will experience missing assets.

### Accessing Product Opener

In this Docker image, Product Opener is configured to run on [localhost](http://world.productopener.localhost/). You may need to add this and other subdomains to your `hosts` file (see your operating system's documentation) to access it.

## Kubernetes

The `productopener` directory contains a <a href="https://helm.sh">Helm</a> template, so that you can set up a new ProductOpener instance on <a href="https://kubernetes.io">Kubernetes</a>. Note that the deployments will create a `PersistentVolumeClaim` (PVC) with `ReadWriteMany` access mode, because the nginx container(s) and Apache container(s) will need to access the volume at the same time. This mode is not supported by every storage plugin. See [access modes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes) for more information.
