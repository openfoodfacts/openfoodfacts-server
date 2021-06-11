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
```console
tail -n 20 filename
```
to check the error logs. You can change the file name depending on which file you want to check.


### For producer's platfrom

The directory for logs of producers platforms is `apache2-pro`.
Go to `~/openfoodfacts-server/docker/logs/apache2-pro` and run

```console
tail -n 20 filename
```


## Running Docker in bash


Go to `cd openfoodfacts/docker` and run

```console
docker ps
```

It will list the all docker images running with their IDs. For the dev environment and pro-dev enviroment, copy docker-backend-id and docker-backend-pro-id respectively. 

and run

```console
docker exec -it docker-backend-id bash
```



## Restarting docker backend without quitting the running environment

If you have made any changes to docker backend files and just want to restart the docker backend, instead of stopping and restarting the complete environment. Open a new terminal and run this script

```console
docker-compose -f docker-compose.yml -f docker-compose-dev.yml -f restart backend
```

It will restart the backend and take less time than using `Ctrl+C` and `./start-dev.sh`.
