# How to use Docker to Develop - a guide

This guide is for developers and newcomers to help them debug and explore Docker.

This page describes how to test and debug your changes once you have set up the project, Product Opener with Docker using [dev environment quick start guide](how-to-quick-start-guide.md).

## Checking logs

### Tail Docker Compose logs

```
make log
```

You will get logs from nginx, mongodb, postgres, etc.

### Tail other logs

Most logs from perl are not (yet ?) displayed on the docker logs,
but are instead available in specific directories.

To see them use:

```
make tail
```

It will `tail -f` all the files present in the `logs/` directory:

* `apache2/error.log`
* `apache2/log4perl.log`
* `apache2/modperl_error.log`
* `apache2/other_vhosts_access.log`
* `nginx/access.log`
* `nginx/error.log`

You can also simply run:
```
tail -f <FILEPATH>
```
to check a specific log.

One of the most important is `log4perl.log`.


### Increasing log verbosity

By default, the `log4perl` configuration `conf/log.conf` matches production
settings. You can tweak that file with your own dev configuration settings and
run `make restart` to reload the changes.

A setting useful for local environments is to set `TRACE` log level:
```
log4perl.rootLogger=TRACE, LOGFILE
```

## Opening a shell in a Docker container

Run the following to open a bash shell within the `backend` container:

```
docker compose exec backend bash
```

You should see `root@<CONTAINER_ID>:/#` (opened root shell): you are now within the Docker container and can begin typing some commands!

### Checking permissions

Navigate to the specific directory and run

```
ls -lrt
```
It will list all directories and their permissions.

### Creating directory

Navigate to your specific directory using `cd` and run

```
mkdir directory-name
```

### Running minion jobs

[Minion](https://docs.mojolicious.org/Minion) is a high-performance job queue for Perl, used in [openfoodfacts-server](https://github.com/openfoodfacts/openfoodfacts-server) for time-consuming import and export tasks. These tasks are processed and queued using the minion jobs queue. Therefore, they are called minion jobs.

Go to `/opt/product-opener/scripts` and run

```
./minion_producers.pl minion job
```

The above command will show the status of minion jobs. Run the following command to launch the minion jobs.

```
./minion_producers.pl minion worker -m production -q pro.openfoodfacts.org
```

### Restarting Apache

Sometimes restarting the whole `backend` container is overkill, and you can just
restart `Apache` from inside the container:

```
apache2ctl -k restart
```

### Exiting the container

Use `exit` to exit the container.

## Making code changes

In the dev environment, any code change to the local directory will be written 
to the container. That said, some code changes require a restart of the `backend` 
container, or rebuilding the NPM assets.


## Getting away from make up

`make up` is a good command for starters,
but it's not the right one to use if you develop on a daily basis, because it may be slow,
as it does a full rebuild, which, in dev mode, should only be necessary in a few cases.

On a daily basis you could better run those:

* `docker compose up` to start and monitor the stack.
* `docker compose restart backend` to account for a code change in a `.pm` file
  (cgi `pl` files do not need a restart)
* `docker compose stop` to stop them all

If some important file changed (like Dockerfile or cpanfile, etc.), or if in doubt,
you can run `docker compose build` (or maybe it's a good time to use `make up` once)

You should explore the [docker compose commands](https://docs.docker.com/compose/reference/).
Most are useful!


### Live reload
To automate the live reload on code changes, you can install the Python package `when-changed`:
```
pip3 install when-changed
when-changed -r docker/ docker-compose.yml .env -c "make restart"                                         # restart backend container on compose changes
when-changed -r lib/ -r docker/ docker-compose.yml -c "docker compose backend restart" # restart Apache on code changes
when-changed -r html/ Dockerfile Dockerfile.frontend package.json -c "make up" # rebuild containers on asset or Dockerfile changes
```

An alternative to `when-changed` is `inotifywait`.


## Run queries on MongoDB database

```
docker compose exec mongodb mongo
```

The above command will open a MongoDB shell, allowing you to use all the `mongo` 
commands to interact with the database:

```
show dbs
use off
db.products.count()
db.products.find({_id: "5053990155354"})
db.products.deleteOne({_id: "5053990155354"})
```

See the [`mongo` shell docs](https://www.mongodb.com/products/shell) for more commands.

## Adding environment variables

If you need some value to be configurable, it is best to set it as an environment variable.

To add a new environment variable `TEST`:

* In a `.env` file, add `TEST=test_val` [local].
* In `.github/workflows/container-deploy.yml`, add `echo "TEST=${{ secrets.TEST }}" >> .env` to the "Set environment variables" build step [remote]. Also add the corresponding GitHub secret `TEST=test_val`.
* In `docker-compose.yml` file, add it under the `backend` > `environment` section.
* In `conf/apache.conf` file, add `PerlPassEnv TEST`.
* In `lib/Config2.pm`, add `$test = $ENV{TEST};`. Also add `$test` to the `EXPORT_OK` list at the top of the file to avoid a compilation error.

The call stack goes like this:

`make up` > `docker compose` > loads `.env` > pass env variables to the `backend` container > pass to `mod_perl` > initialized in `Config2.pm`.

## Managing multiple deployments

To juggle between multiple local deployments (e.g: to run different flavors of Open Food Facts on the same host),
there are different possible strategies.

### a set env script

docker compose takes its settings from, in decreasing priority:
* the environment
* the `.env` file

So one strategy to have a different instance,
can be to keep the same `.env` file, but override some env variables to tweak the configuration.
This is a good strategy for the pro platform.

For this case we have a 
[`setenv.sh`](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/env/setenv.sh)
script.

To use it, open a terminal, where you want to be in pro environment and simply use:

```bash
. setenv.sh off-pro
```

then you can use whatever docker compose command.

**Note:** This terminal will remain in `pro` mode until you end its session.

See also [Developing on the producers platform](how-to-develop-producer-platform.md)

### different .env file

This strategy might be the right one if your settings differ a lot.

You will need:

* Multiple `.env` files (one per deployment), such as:

  * `.env.off` : configuration for Open Food Facts dev env.
  * `.env.off-pro` : configuration for Open Food Facts Producer's Platform dev env.
  * `.env.obf`: configuration for Open Beauty Facts dev env.
  * `.env.opff`: configuration for Open Pet Food Facts dev env.


* `COMPOSE_PROJECT_NAME`, `COMPOSE_PROFILES`,  `PRODUCT_OPENER_DOMAIN`, `PRODUCT_OPENER_PORT`, `PRODUCT_OPENER_FLAVOR` and `PRODUCT_OPENER_FLAVOR_SHORT` set to different values in each `.env` file, so that container names across deployments are unique and frontend containers don't port-conflict with each other. See example below.

To switch between configurations, set `ENV_FILE` before running `make` commands,
(or `docker compose` command):

```
ENV_FILE=.env.off-pro make up # starts the OFF Producer's Platform containers.
ENV_FILE=.env.obf     make up # starts the OBF containers.
ENV_FILE=.env.opff    make up # starts the OPFF containers.
```

or export it to keep it for a while:

```
export ENV_FILE=.env.off # going to work on OFF for a while
make up
make restart
make down
make log
```

A good strategy is to have multiple terminals open, one for each deployment:

* `off` [Terminal 1]:
  ```
  export ENV_FILE=.env.off
  make up
  ```

* `off-pro` [Terminal 2]:
  ```
  export ENV_FILE=.env.off-pro
  make up
  ```

* `obf` [Terminal 3]:
  ```
  export ENV_FILE=.env.obf
  make up
  ```

* `opff` [Terminal 3]:
  ```
  export ENV_FILE=.env.opff
  make up
  ```

**Note:** the above case of 4 deployments is ***a bit ambitious***, since ProductOpener's `backend` container takes about ~6GB of RAM to run, meaning that the above 4 deployments would require a total of 24GB of RAM available.

**Example:** if you already have Open Food Facts up and running and you would like to have Open Beauty Facts as well. Then, copy `.env` to `.env.obf` and modify the following variables:
```
COMPOSE_PROJECT_NAME=po_off
COMPOSE_PROFILES=off
PRODUCT_OPENER_DOMAIN=openfoodfacts.localhost
PRODUCT_OPENER_PORT=80
PRODUCT_OPENER_FLAVOR=openfoodfacts
PRODUCT_OPENER_FLAVOR_SHORT=off
```
to
```
COMPOSE_PROJECT_NAME=po_obf
COMPOSE_PROFILES=obf
PRODUCT_OPENER_DOMAIN=openbeautyfacts.localhost
PRODUCT_OPENER_PORT=81
PRODUCT_OPENER_FLAVOR=openbeautyfacts
PRODUCT_OPENER_FLAVOR_SHORT=obf
```
Run:
```
export ENV_FILE=.env.obf
make dev
```
If you have error like `Errors in the labels taxonomy definition at /opt/product-opener/lib/ProductOpener/Tags.pm line 1622.`, due to conflict between taxonomies, a small hack is to comment the lines (it appears 2 times in the file) raising error in the **Tags.pm** file. 
