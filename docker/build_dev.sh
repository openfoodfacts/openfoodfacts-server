#!/bin/sh
#if mac:
  brew cask install docker
#else:
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
docker-compose -f ./docker-compose.yml -f ./docker-compose.dev.yml build backend
