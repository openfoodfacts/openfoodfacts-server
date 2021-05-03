#!/bin/sh
#if mac:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  brew cask install docker
  # opening docker for the first time in GUI mode to grant it priviledges
  open docker
#else:
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
docker-compose -f ./docker-compose.yml -f ./docker-compose.dev.yml build backend
