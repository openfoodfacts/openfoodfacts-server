#!/bin/sh
docker-compose -f ./docker-compose.yml -f ./docker-compose.dev.yml build backend
