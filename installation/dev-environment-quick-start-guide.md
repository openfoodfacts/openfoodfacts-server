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

## 3. Build your environment
The fastest way is to use the ready-to-use scripts on the Open Food Facts GitHub repo.
```console
$ cd ./openfoodfacts-server/docker/
$ ./build_dev.sh
$ ./start_dev.sh
```
The first build can take between 10 and 30 minutes depending on your machine and internet connection (broadband connection heavily recommended, as this will download Docker base images, install Debian and Perl modules in preparation of the final container image).
This will build a new backend image from your local source files. Note that this binds the docker container to your local development directory. Therefore, it is not required to rebuild the container image after changing the source files.

To be complete, you also to have to build some front-end assets:

Open a new terminal and

```console
$ ./build_npm.sh # just once
```

Optionally — recommended —, also install a test product base with product pictures (328 MB):

```console
$ docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec backend bash /opt/scripts/import_sample_data.sh
```

If you are running Docker on Windows, you should edit your hosts file (C:\Windows\System32\drivers\etc\hosts) and add the following line :
```text
127.0.0.1 world.productopener.localhost fr.productopener.localhost static.productopener.localhost ssl-api.productopener.localhost fr-en.productopener.localhost 
```

You’re done! Check http://localhost/

Note: it’s possible that you don’t see immediately the test product database: create an account and login, it should appear.

### Setting up producers platform

The process for setting up the producer’s platform is almost the same. The scripts to run it on a local machine are different. 

```console
$ cd ./openfoodfacts-server/docker/
$ ./build_pro_dev.sh
$ ./start_pro_dev.sh
```
Note: You will have to build front-end assets for the producer’s platform as well.  

The link for the producer’s platform is http://world.pro.productopener.localhost/ 


## 4. Starting and stopping environment

**Stopping**

To stop the environment, you just have to type [Ctrl+c] in the terminal where you launched start_dev.

**Restarting**

```console
$ ./start_dev.sh
```

## 5. Going further

Deleting all that stuff:
```console
$ docker-compose -f docker-compose.yml -f docker-compose.dev.yml down
$ docker container prune
$ docker volume prune
$ docker rmi $(docker images -q)
```
More documentation: https://github.com/openfoodfacts/openfoodfacts-server/tree/master/docker

### 6. Appendix
#### Changing ports

By default, the containers run using port 80. If you need to change this to ie. 8080, update the port of the `frontend` service in `docker/docker-compose.yml`:
```
    ports:
      - 8080:80
```

and `/docker/backend-dev/conf/Config2.pm`:
```perl
# server constants
$server_domain = "productopener.localhost:8080";
```

Also, you need to add a `cookie_domain` to the `%server_options` the same file, so that the software does not try to use the port for the cookie host.
```perl
%server_options = (
        private_products => 0,  # 1 to make products visible only to the owner (producer platform)
        export_servers => { public => "off", experiment => "off-exp" },
        minion_backend => { Pg => 'postgresql://productopener:productopener@postgres/minion' },
        cookie_domain => 'productopener.localhost'
);
```
Once you are done building your environment, go to http://localhost:8080/


### 7. Optional - Import full mongodb dump
The default docker environnement contains only ~120 products. If you need a full db with more than 1 millions products, you can import mongodb dump (1.7GB). Note that this doesn't contain full product details.
```console
$ wget https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.tar.gz
$ docker cp openfoodfacts-mongodbdump.tar.gz docker_mongodb_1:/data/db
$ docker exec -it docker_mongodb_1 bash
$ cd /data/db
$ tar -xzvf openfoodfacts-mongodbdump.tar.gz 
$ mongorestore
$ exit
```
