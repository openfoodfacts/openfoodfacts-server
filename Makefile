#!/usr/bin/make

NAME = "ProductOpener"

#-------#
# Admin #
#-------#
up:
	docker-compose up -d --remove-orphans --build backend frontend

down:
	docker-compose down

restart:
	docker-compose restart backend

log:
	docker-compose logs -f

tail:
	tail -f logs/**/*

import_sample_data:
	docker-compose exec backend bash /opt/product-opener/scripts/import_sample_data.sh

status:
	docker ps

prune:
	docker system prune -af

dev: up build_npm import_sample_data

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
