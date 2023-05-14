#!/bin/sh

ENV_FILE="${ENV_FILE:-.env}"
RET_CODE=0
for service in `docker-compose --env-file=${ENV_FILE} config  --service | tr '\n' ' '`; do 
if [ -z `docker-compose ps -q $service` ] || [ -z `docker ps -q --no-trunc | grep $(docker-compose --env-file=${ENV_FILE} ps -q $service)` ]; then
    echo "$service: DOWN"
    RET_CODE=1
else
    echo "$service: UP"
fi
done;
exit $RET_CODE;
