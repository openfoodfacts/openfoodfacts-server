# Docker Developer's Guide

This guide is for developers and newcomers to help them debug and explore Docker.

This page describes how to test and debug your changes once you have set up the project, Product Opener with Docker using [dev environment quick start guide](./dev-environment-quick-start-guide.md).

## Checking logs

### Tail Docker Compose logs

```
make log
``` 

### Tail other logs

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


## Opening a shell in a Docker container

Run the following to open a bash shell within the `backend` container:

```
docker-compose exec backend bash
```

You should see `root@<CONTAINER_ID>:/#` (opened root shell): you are now within the Docker container and can begin typing some commands !

### Checking permissions

Navigate to the directory the specific directory and run

```
ls -lrt
```
It will list all the directories and their permission status.

### Creating directory

Navigate to your specific directory using `cd` command and run

```
mkdir directory-name
```

### Running minion jobs

[Minion](https://docs.mojolicious.org/Minion) is a high-performance job queue for Perl. [Minion](https://docs.mojolicious.org/Minion) is used in [openfoodfacts-server](https://github.com/openfoodfacts/openfoodfacts-server) for time-consuming import and export tasks. These tasks are processed and queued using the minion jobs queue. Therefore, are called minion jobs.

Go to `/opt/product-opener/scripts` and run

```
./minion_producers.pl minion job
```

The above command will show the status of minion jobs. Run the following command to launch the minion jobs.

```
./minion_producers.pl minion worker -m production -q pro.openfoodfacts.org
```

### Restarting Apache
```
apache2ctl -k restart
```

### Exiting the container

Use `exit` to exit the container.


## Restarting backend without quitting the running environment

If you have made any changes to backend code and just want to restart it, run:

```
make restart
```

**Note:** restart is necessary only if you make changes to files in the `lib/` directory (needs recompilation), but not if you make changes to files in the `cgi/` directory.

## Using multiple deployments

To manage multiple deployments, you will need:

* Multiple `.env` files (one per deployment), such as:

  * `.env.off` : configuration for Open Food Facts dev env.
  * `.env.off-pro` : configuration for Open Food Facts Producer's Platform dev env.
  * `.env.obf`: configuration for Open Beauty Facts dev env.
  * `.env.opff`: configuration for Open Ped Food Facts dev env.


* The variable `COMPOSE_PROJECT_NAME` should be set to different values in each `.env` file, so that container names are unique.

To switch between configurations, set `ENV_FILE` before running any `make` commands:

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
...
```

You can even have multiple terminals open, one for each deployment:

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
