## Logging Bugs



1. Go to `~/openfoodfacts-server/docker/logs/apache2` and run

2. Run
```
ls
```
It will list all the files. 

* `error.log` 
* `log4perl.log`
* `modperl_error.log`

3. Run 
```console
tail -n 20 filename
```
to check the error logs. You can change the file name depending on which file you want to check.

### For producer's platfrom

Go to `~/openfoodfacts-server/docker/logs/apache2-pro` and repeat the steps 2 and 3. 








## Running Docker in bash


Go to `cd openfoodfacts/docker` and run

```console
docker ps
```

It will show the list of running docker images with their IDs. 

Copy docker-backend-id and run

```console
docker exec -it docker-backend-id bash
```

