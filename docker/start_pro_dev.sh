#!/bin/sh
docker compose -f ./docker-compose.pro.yml -f ./docker-compose.pro.dev.yml  up
