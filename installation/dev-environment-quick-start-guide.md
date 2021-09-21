# Dev environment quick start guide

This guide will allow you to rapidly build a ready-to-use development environment for **Product Opener** running in Docker.

First setup time estimate is `~10mn` with the following specs:
* `8GB` RAM dedicated to Docker client
* `6` CPUs dedicated to Docker client
* `12MB/s` internet speed

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
>
> Be aware Open Food Facts server takes more than 1.3 GB (2019/11).

Choose your prefered way to clone, either:

```console
$ git clone git@github.com:openfoodfacts/openfoodfacts-server.git
```

or

```console
$ git clone https://github.com/openfoodfacts/openfoodfacts-server.git
```

If you are running Docker on Windows, please use the following git clone option:

```console
$ git clone -c core.symlinks=true git@github.com:openfoodfacts/openfoodfacts-server.git
```

Go to the cloned directory:

```console
cd openfoodfacts-server/
```

## 3. [Optional] Review Product Opener's environment

**Note: you can skip this step for the first setup since the default `.env` in the repo contains all the default values required to get started.**

Before running the `docker-compose` deployment, you can review and configure
Product Opener's environment ([`.env`](../.env) file).


The `.env` file contains ProductOpener default settings:
* `PRODUCT_OPENER_DOMAIN` can be set to different values based on which **OFF flavor** is run.
* `PRODUCT_OPENER_PORT` can be modified to run NGINX on a different port. Useful when running **multiple OFF flavors** on different ports on the same host. Default port: `80`.
* `PRODUCT_OPENER_FLAVOR` can be modified to run different flavors of OpenFoodFacts, amongst `openfoodfacts` (default), `openbeautyfacts`, `openpetfoodfacts`, `openproductsfacts`.
* `PRODUCERS_PLATFORM` can be set to `1` to build / run the **producer platform**.
* `ROBOTOFF_URL` can be set to **connect with a Robotoff instance**.
* `GOOGLE_CLOUD_VISION_API_KEY` can be set to **enable OCR using Google Cloud Vision**.
* `CROWDIN_PROJECT_IDENTIFIER` and `CROWDIN_PROJECT_KEY` can be set to **run translations**.
* `GEOLITE2_PATH`, `GEOLITE2_ACCOUNT_ID` and `GEOLITE2_LICENSE_KEY` can be set to **enable Geolite2**.
* `TAG` is set to `latest` by default, but you can specify any Docker Hub tag for the `frontend` / `backend` images. Note that this is useful only if you use pre-built images from the Docker Hub (`docker/prod.yml` override); the default dev setup (`docker/dev.yml`) builds images locally.

The `.env` file also contains some useful Docker Compose variables:
* `COMPOSE_PROJECT_NAME` is the compose project name that sets the **prefix to every container name**. Do not update this unless you know what you're doing.
* `COMPOSE_FILE` is the `;`-separated list of Docker compose files that are included in the deployment:
  * For a **development**-like environment, set it to `docker-compose.yml;docker/dev.yml` (default)
  * For a **production**-like environment, set it to `docker-compose.yml;docker/prod.yml;docker/mongodb.yml`
  * For more features, you can add:
    * `docker/admin-uis.yml`: add the Admin UIS container
    * `docker/geolite2.yml`: add the Geolite2 container
    * `docker/perldb.yml`: add the Perl debugger container
* `COMPOSE_SEPARATOR` is the separator used for `COMPOSE_FILE`.

**Note:** you can use a different `.env` file by setting the environment variable `ENV_FILE` (e.g: `export ENV_FILE=/path/to/my/custom/.env.prod`).

## 4. Build your dev environment

From the repository root, run:

```console
$ make dev
```

_If docker complains about ERROR: could not find an available, non-overlapping IPv4 address pool among the defaults to assign to the network it can be solved by adding {"base":"172.80.0.0/16","size":24}, {"base":"172.90.0.0/16","size":24} to default-address-pools in /etc/docker/daemon.json and then restarting the docker daemon. Credits to https://theorangeone.net/posts/increase-docker-ip-space/ for this solution._

The command will run 2 subcommands:
* `make up`: **Build and run containers** from the local directory and bind local code files, so that you do not have to rebuild everytime.
* `make import_sample_data`: **Load sample data** into `mongodb` container (~100 products).

***Notes:***

* The first build can take between 10 and 30 minutes depending on your machine and internet connection (broadband connection heavily recommended, as this will download Docker base images, install Debian and Perl modules in preparation of the final container image).

* You might not immediately see the test products: create an account, login, and they should appear.

* If docker complains about `ERROR: could not find an available, non-overlapping IPv4 address pool among the defaults to assign to the network` it can be solved by adding `{"base":"172.80.0.0/16","size":24}, {"base":"172.90.0.0/16","size":24}` to `default-address-pools` in `/etc/docker/daemon.json` and then restarting the docker daemon. Credits to https://theorangeone.net/posts/increase-docker-ip-space/ for this solution._

**Hosts file:**

Since the default `PRODUCT_OPENER_DOMAIN` in the `.env` file is set to `productopener.localhost`, add the following to your hosts file (Windows: `C:\Windows\System32\drivers\etc\hosts`; Linux/MacOSX: `/etc/hosts`):

```text
127.0.0.1 world.productopener.localhost fr.productopener.localhost static.productopener.localhost ssl-api.productopener.localhost fr-en.productopener.localhost
```

### You're done ! Check http://productopener.localhost/ !

### Going further

To learn more about developing with Docker, see the [Docker developer's guide](./docker-developer-guide.md).

## Visual Studio Code

This repository comes with a configuration for Visual Studio Code (VS Code) [development containers (devcontainer)](https://code.visualstudio.com/docs/remote/containers). This enables some Perl support in VS Code without the need to install the correct Perl version and modules on your local machine.

To use the devcontainer, install [prerequisites](#1-prerequisites), [clone the repository from GitHub](#2-clone-the-repository-from-github), and [(optionally) review Product Opener's environment](#3-optional-review-product-openers-environment). Additionally, install [Visual Studio Code](https://code.visualstudio.com/). VS Code will automatically recommend some extensions, but if you don't want to install all of them, please do install [Remote - Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) manually. You can then use the extension command **Remote-Containers: Reopen Folder in Container**, which will automatically build the container and start the services. No need to use `make`!
