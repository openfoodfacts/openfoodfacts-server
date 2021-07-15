"Developer's Guide" is for developers and newcomers to help them in debugging and exploring docker.
This page describes how to test and debug your changes once you have set up the project, Product Opener with Docker using [dev environment quick start guide](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/installation/dev-environment-quick-start-guide.md).


## Logging Bugs

Go to `~/openfoodfacts-server/docker/logs/apache2` and run

```
ls
```
It will list all the files present in the directory, e.g.,

* `error.log`
* `log4perl.log`
* `modperl_error.log`

Run
```
tail -n 20 filename
```
to check the error logs. You can change the file name depending on which file you want to check.

### For producer's platform

The directory for logs of producer’s platforms is `apache2-pro`.
Go to `~/openfoodfacts-server/docker/logs/apache2-pro` and run

```
tail -n 20 filename
```


## Running Docker in bash

Go to `cd openfoodfacts/docker` and run

```
docker ps
```

It will list all docker images running with their IDs. For the dev environment and pro-dev environment, copy productopener-backend-dev-id and docker-backend-pro-id respectively.

and run

```
docker exec -it productopener-backend-dev-id bash
```

It will lead to `root@productopener-backend-dev-id:/#`

### Checking permission

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

### Exiting from bash terminal

Use `exit` to exit from the bash terminal.


## Restarting docker backend without quitting the running environment

If you have made any changes to docker backend files and just want to restart the docker backend, instead of stopping and restarting the complete environment. Open a new terminal and run this script

```
docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f restart backend
```

It will restart the backend and take less time than using `Ctrl+C` and `./start-dev.sh`.
