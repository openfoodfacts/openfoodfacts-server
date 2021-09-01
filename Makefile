#!/usr/bin/make

NAME = "ProductOpener"
ENV_FILE ?= .env

#-------#
# Admin #
#-------#
up:
	docker-compose --env-file=${ENV_FILE} up -d --remove-orphans --build

down:
	docker-compose --env-file=${ENV_FILE} down

restart:
	docker-compose --env-file=${ENV_FILE} restart backend frontend

log:
	docker-compose --env-file=${ENV_FILE} logs -f

tail:
	tail -f logs/**/*

status:
	docker-compose --env-file=${ENV_FILE} ps

prune:
	docker system prune -af


dev: up build_npm import_sample_data

#--------#
# Import #
#--------#
import_sample_data:
	docker-compose --env-file=${ENV_FILE} exec backend bash /opt/product-opener/scripts/import_sample_data.sh

import_prod_data:
	wget https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.tar.gz
	docker cp openfoodfacts-mongodbdump.tar.gz po_mongodb_1:/data/db
	docker-compose --env-file=${ENV_FILE} exec mongodb /bin/sh -c "cd /data/db && tar -xzvf openfoodfacts-mongodbdump.tar.gz && mongorestore"

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
