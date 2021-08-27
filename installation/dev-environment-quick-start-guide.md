# 45 minutes to build Open Food Facts dev environment
This guide will allow you to build a ready-to-use development environment for Open Food Facts main application, called Product Opener.

Product Opener is a big app that require many languages and dependencies. The build process takes around 45 minutes with a 5 years-or-less computer and a good broadband internet connection (at least 5-10 MBits/s).


## 1. Prerequisites
Docker is the easiest way to install the Open Food Facts server, play with it, and even modify the code.

Docker provides an isolated environment, very close to a Virtual Machine. This environment contains everything required to launch the Open Food Facts server. There is **no need to install** Perl, Perl modules, Nginx, nor Apache separately.

Install docker:
- [Docker CE](https://docs.docker.com/install/#supported-platforms)
  - If you run e.g. Debian, don't forget to add your user to the `docker` group!
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Command-line completion](https://docs.docker.com/compose/completion/)


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

## 3. Setup the environment

The `.env` file contains ProductOpener default settings:
* `PRODUCERS_PLATFORM` can be set to 1 to build / run the producer platform.
* `ROBOTOFF_URL` can be set to connect with a Robotoff instance.
* `GOOGLE_CLOUD_VISION_API_KEY` can be set to enable OCR using Google Cloud Vision.
* `CROWDIN_PROJECT_IDENTIFIER` and `CROWDIN_PROJECT_KEY` can be set to run translations.
* `GEOLITE2_PATH` and `GEOLITE2_LICENSE_KEY` can be set to enable Geolite2.

## 4. Build your dev environment

From the repository root, run:

```console
$ make dev
```

The command will:
* **Build the backend container** from local directory and bind local code files, so that you do not have to rebuild everytime.
* **Build NPM assets** and bind them to your local directory `node_modules/` and `html/`.
* **Load some data** into the `mongodb`.

***Note:*** The first build can take between 10 and 30 minutes depending on your machine and internet connection (broadband connection heavily recommended, as this will download Docker base images, install Debian and Perl modules in preparation of the final container image).


Since the default domain is set to `productopener.localhost`, add the following to your hosts file (Windows: `C:\Windows\System32\drivers\etc\hosts`; Linux/MacOSX: `/etc/hosts`):
```text
127.0.0.1 world.productopener.localhost fr.productopener.localhost static.productopener.localhost ssl-api.productopener.localhost fr-en.productopener.localhost 
```

You’re done! Check http://productopener.localhost/

***Note:*** it is possible that you will not immediately see the test product database: create an account, login, and it should appear.

## 5. Starting, stopping, restarting Docker containers

```console
$ make up      # start the containers
$ make down    # stop the containers
$ make restart # restart the containers
$ make prune   # prune unused Docker artifacts
```

### 6. Appendix

#### Changing ports

By default, the containers run using port 80. If you need to change this to ie. 8080, override the existing port of the `frontend` service in `docker/dev.yml`:
```
    ports:
      - 8080:80
```
Once you are done building your environment, go to http://localhost:8080/

#### Import full mongodb dump
The default docker environnement contains only ~120 products. If you need a full db with more than 1 millions products, you can import mongodb dump (1.7GB).
```console
$ wget https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.tar.gz
$ docker cp openfoodfacts-mongodbdump.tar.gz docker_mongodb_1:/data/db
$ docker exec -it docker_mongodb_1 bash
$ cd /data/db
$ tar -xzvf openfoodfacts-mongodbdump.tar.gz 
$ mongorestore
$ exit
```
