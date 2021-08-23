#!/usr/bin/make

NAME = "ProductOpener"

#-----#
# Dev #
#-----#
dev: build_npm start load_dev

start:
	docker-compose -f docker-compose.yml -f docker/dev.yml -f docker/vscode.yml up -d --remove-orphans --build backend
	docker-compose -f docker-compose.yml -f docker/dev.yml -f docker/vscode.yml up -d --remove-orphans

stop:
	docker-compose down

restart:
	docker-compose restart

log:
	docker-compose logs -f

load_dev:
	docker-compose exec backend bash /opt/product-opener/scripts/import_sample_data.sh

status:
	docker ps

#------------#
# Production #
#------------#
prod: clean
	docker-compose -f docker-compose.yml -f docker/prod.yml -f docker/geolite2.yml up -d --remove-orphans

#-------#
# Build #
#-------#
build_npm:
	docker run --rm -it -v node_modules:/mnt/node_modules -v $(realpath ./):/mnt -w /mnt node:lts npm install
	docker run --rm -it -v node_modules:/mnt/node_modules -v $(realpath ./):/mnt -w /mnt node:lts npm run build

#-----------#
# Utilities #
#-----------#
info:
	@echo "ProductOpener version: ${VERSION}"

clean:
	rm -rf node_modules/
	rm -rf tmp/
	rm -rf logs/
