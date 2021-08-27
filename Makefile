#!/usr/bin/make

NAME = "ProductOpener"
DEV_ARGS = -f docker-compose.yml -f docker/dev.yml -f docker/mongodb.yml
PROD_ARGS = -f docker-compose.yml -f docker/prod.yml -f docker/geolite2.yml

#-----#
# Dev #
#-----#
dev: up build_npm import_sample_data

up:
	docker-compose ${DEV_ARGS} up -d --remove-orphans --build backend frontend

down:
	docker-compose ${DEV_ARGS} down

restart:
	docker-compose ${DEV_ARGS} restart

log:
	docker-compose ${DEV_ARGS} logs -f

tail:
	tail -f logs/**/*

import_sample_data:
	docker-compose ${DEV_ARGS} exec backend bash /opt/product-opener/scripts/import_sample_data.sh

status:
	docker ps

prune:
	docker system prune -af

#------------#
# Production #
#------------#
prod: clean
	docker-compose ${PROD_ARGS} up -d --remove-orphans

#-------#
# Build #
#-------#
build_npm:
	docker run --rm -it -v $(realpath ./)/node_modules:/mnt/node_modules -v $(realpath ./):/mnt -w /mnt node:lts npm install
	docker run --rm -it -v $(realpath ./)/node_modules:/mnt/node_modules -v $(realpath ./):/mnt -w /mnt node:lts npm run build

#-----------#
# Utilities #
#-----------#
info:
	@echo "${NAME} version: ${VERSION}"

clean:
	rm -rf node_modules/
	rm -rf tmp/
	rm -rf logs/
