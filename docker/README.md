# Product Opener on Docker #

This directory contains some experimental files for running Product Opener on [Docker](https://docker.com).

## Building the Images ##

Product Opener has not been published to Docker Hub, because I assume that there would be very little advantage in that. However, the Dockerfiles in this directory can be used to build your own Docker images from source.

### Base image ###

In order to reducing the amout of time and work needed to rebuild the program image, we have two base images that the actual images are built on. Build them using

```
docker build -t productopener/backend-base backend-base
docker build -t productopener/backend-base-cpan backend-base-cpan
```

### Source from Git ###

Use this if you want to run Product Opener with the source code from Git.

```
copy ..\cpanfile backend-dev\product-opener\cpanfile # This is currently required because symlinking it doesn't work well.
docker build -t productopener/backend-git backend-git
docker build -t productopener/frontend-git frontend-git
```

### Source from local directory ###

Use this for local development.

```
docker build -t productopener/backend-dev backend-dev
```

## Deploy ##

In this repository, the service dependencies are expressed in [compose](https://docs.docker.com/compose/compose-file/) files.

### Source from Git ###

If you built `productopener/backend-git` and `productopener/frontend-git` above, run

```
docker stack deploy --compose-file=docker-compose-git.yml po
```

### Source from local directory ###

If you built `productopener/backend-dev`, run

```
docker stack deploy --compose-file=docker-compose-dev.yml po
```

## Accessing Product Opener ##

In this Docker image, Product Opener is configured to run on [localhost](http://world.productopener.localhost/). You may need to add this domain/subdomain to your `hosts` file (see your operating system's documentation) to access it.