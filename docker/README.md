# Product Opener on Docker

This directory contains some experimental files for running Product Opener on [Docker](https://docker.com).

## Building the Images

Product Opener has not been published to Docker Hub, because I assume that there would be very little advantage in that. However, the Dockerfiles in this directory can be used to build your own Docker images from source.

### All in One Container

Uses one container to host Apache and nginx, much like described in the [Wiki](https://en.wiki.openfoodfacts.org/Infrastructure).

#### Building the Container

```bash
docker-compose -f docker-compose-aio.yml build
```

#### Deploy

```bash
docker-compose -f docker-compose-aio.yml up
```

### Split Containers

Uses separate containers for application layer (Apache) and the reverse proxy (nginx).

#### Building the Container

```bash
docker build -t productopener/backend-dev -f backend-dev/Dockerfile ..
```

### Deploy

In this repository, the service dependencies are expressed in [compose](https://docs.docker.com/compose/compose-file/) files.

#### Source from local directory

If you built `productopener/backend-dev`, run

```bash
docker stack deploy --compose-file=docker-compose-dev.yml po
```

### Accessing Product Opener

In this Docker image, Product Opener is configured to run on [localhost](http://world.productopener.localhost/). You may need to add this domain/subdomain to your `hosts` file (see your operating system's documentation) to access it.
