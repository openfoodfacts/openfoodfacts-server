# Dev environment quick start guide

This guide will allow you to rapidly build a ready-to-use development environment for **Product Opener** running in Docker.


## 1. Prerequisites
**Docker** is the easiest way to install the Open Food Facts server, play with it, and even modify the code.

Docker provides an isolated environment, very close to a Virtual Machine. This environment contains everything required to launch the Open Food Facts server. There is **no need to install** Perl, Perl modules, Nginx, nor Apache separately.

**Installation steps:**
- [Install Docker CE](https://docs.docker.com/install/#supported-platforms)
  - If you run e.g. Debian, don't forget to add your user to the `docker` group!
- [Install Docker Compose](https://docs.docker.com/compose/install/)
- [Enable command-line completion](https://docs.docker.com/compose/completion/)
- [Install Make for Windows](http://gnuwin32.sourceforge.net/packages/make.htm) (if running on Windows)


## 2. Clone the repository from GitHub

> You must have a GitHub account if you want to contribute to Open Food Facts development, but it’s not required if you just want to see how it works.

> Be aware Open Food Facts server takes more than 1.3 GB (2019/11).

Choose your prefered way to clone, either:

```console
$ git clone git@github.com:openfoodfacts/openfoodfacts-server.git
```

or

```console
$ git clone https://github.com/openfoodfacts/openfoodfacts-server.git
```

If you are running Docker on Windows, please use the following git clone option :
```console
$ git clone -c core.symlinks=true git@github.com:openfoodfacts/openfoodfacts-server.git
```

## 3. Setup Product Opener's environment

Before running the `docker-compose` deployment, you need to review and configure
Product Opener's environment ([`.env`](../.env) file).

The `.env` file contains ProductOpener default settings:
* `PRODUCT_OPENER_DOMAIN` can be set to different values based on which flavor is run.
* `PRODUCT_OPENER_PORT` can be set to different values to support multiple deployments (they would conflict if on the same port !).
* `PRODUCERS_PLATFORM` can be set to `1` to build / run the producer platform.
* `ROBOTOFF_URL` can be set to connect with a Robotoff instance.
* `GOOGLE_CLOUD_VISION_API_KEY` can be set to enable OCR using Google Cloud Vision.
* `CROWDIN_PROJECT_IDENTIFIER` and `CROWDIN_PROJECT_KEY` can be set to run translations.
* `GEOLITE2_PATH`, `GEOLITE2_ACCOUNT_ID` and `GEOLITE2_LICENSE_KEY` can be set to enable Geolite2.

The `.env` file also contains three useful Docker Compose variables:
* `TAG` is set to `latest` by default, but you can specify any Docker Hub tag for the `frontend` / `backend` images.
* `COMPOSE_PROJECT_NAME` is the compose project name that sets the prefix to every container name. Do not update this unless you know what you're doing.
* `COMPOSE_FILE` is the `;`-separated list of Docker compose files that are included in the deployment:
  * For a **development**-like environment, set it to `docker-compose.yml;docker/dev.yml;docker/mongodb.yml` (default)
  * For a **production**-like environment, set it to `docker-compose.yml;docker/prod.yml`
  * For more features, you can add:
    * `docker/admin-uis.yml`: add the Admin UIS container
    * `docker/geolite2.yml`: add the Geolite2 container
    * `docker/perldb.yml`: add the Perl debugger container
    * `docker/vscode.yml`: add the VSCode container
    * `docker/mongodb.yml`: add the MongoDB container

You can use a different `.env` file by setting the environment variable `ENV_FILE` (e.g: `export ENV_FILE=/path/to/my/custom/.env.prod`).

**Hosts file:**

Since the default domain is set to `productopener.localhost`, add the following to your hosts file (Windows: `C:\Windows\System32\drivers\etc\hosts`; Linux/MacOSX: `/etc/hosts`):
```text
127.0.0.1 world.productopener.localhost fr.productopener.localhost static.productopener.localhost ssl-api.productopener.localhost fr-en.productopener.localhost 
```

## 4. Build your dev environment

From the repository root, run:

```console
$ make dev
```

The command will run 3 subcommands:
* `make up`: **Run all containers** from the local directory and bind local code files, so that you do not have to rebuild everytime.
* `make build_npm`: **Build static assets (JS, CSS, HTML, etc...)** in local folders `node_modules/` and `html`, and bind them to the running frontend (NGINX) container.
* `make import_sample_data`: **Load sample data** into `mongodb` container (~100 products).

***Notes:*** 

* The first build can take between 10 and 30 minutes depending on your machine and internet connection (broadband connection heavily recommended, as this will download Docker base images, install Debian and Perl modules in preparation of the final container image).

* You might not immediately see the test products: create an account, login, and they should appear.

### You're done ! Check http://productopener.localhost/ !

## 5. Starting, stopping, restarting Docker containers, and more...

```console
$ make up      # start the containers
$ make down    # stop the containers
$ make restart # restart the containers
$ make log     # get `docker-compose` logs (does not include all logs)
$ make tail    # get other logs (`Apache`, `mod_perl`, etc...) bound to the local `logs` directory
$ make prune   # prune unused Docker artifacts
```

## 6. Appendix

### Changing ports

By default, the containers run using port 80. If you need to change this to ie. 8080, override the existing port of the `frontend` service in `docker/dev.yml`:
```
    ports:
      - 8080:80
```
Once you are done building your environment, go to http://localhost:8080/

### Import full mongodb dump
The default docker environnement contains only ~120 products. If you need a full db with more than 1 millions products, you can import mongodb dump (1.7GB).
```console
$ make import_prod_data
```

**Note:** it might take a while (up to 10mn) to import the full production database.


### Going further
To learn more about Docker and how to develop with it, see the [Docker developer's guide]((./docker-developer-guide.md)).
