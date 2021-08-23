#!/usr/bin/make

NAME = "ProductOpener"

setup: clean start npm load log

prod:
	docker-compose -f docker-compose.yml -f docker/prod.yml -f docker/geolite2.yml up -d --remove-orphans

start:
	docker-compose -f docker-compose.yml -f docker/dev.yml -f docker/vscode.yml up -d --remove-orphans --build backend

stop:
	docker-compose down

restart:
	docker-compose restart

load:
	docker-compose exec backend bash /opt/product-opener/scripts/import_sample_data.sh

npm:
	docker run --rm -it -v node_modules:/mnt/node_modules -v $(PWD):/mnt -w /mnt node:lts npm install
	docker run --rm -it -v node_modules:/mnt/node_modules -v $(PWD):/mnt -w /mnt node:lts npm run build

log:
	docker-compose -f docker-compose.yml -f docker/dev.yml logs -f

status:
	docker ps

info:
	@echo "ProductOpener version: ${VERSION}"

clean:
	rm -rf node_modules/
	rm -rf tmp/
	rm -rf logs/
