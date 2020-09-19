#!/bin/sh
set -e

docker-compose \
  -f ./docker-compose.yml \
  -f ./docker-compose.dev.yml \
  -f ./docker-compose.perldb.yml \
  up -d

docker attach socat ||
  docker-compose \
    -f ./docker-compose.yml \
    -f ./docker-compose.dev.yml \
    -f ./docker-compose.perldb.yml \
    down
