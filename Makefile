#!/usr/bin/make

NAME = "ProductOpener"
ENV_FILE ?= .env
MOUNT_POINT ?= /mnt
HOSTS=127.0.0.1 world.productopener.localhost fr.productopener.localhost static.productopener.localhost ssl-api.productopener.localhost fr-en.productopener.localhost
DOCKER_COMPOSE=docker-compose --env-file=${ENV_FILE}

.DEFAULT_GOAL := dev

#------#
# Info #
#------#
info:
	@echo "${NAME} version: ${VERSION}"

hello:
	@echo "🥫 Welcome to the Open Food Facts dev environment setup!"
	@echo "🥫 Note that the first installation might take a while to run, depending on your machine specs."
	@echo "🥫 Typical installation time on 8GB RAM, 4-core CPU, and decent network bandwith is about 10 min."
	@echo "🥫 Thanks for contributing to Open Food Facts!"
	@echo ""

goodbye:
	@echo "🥫 Cleaning up dev environment (remove containers, remove local folder binds, prune Docker system) …"

#-------#
# Local #
#-------#
dev: hello up setup_incron import_sample_data refresh_product_tags
	@echo "🥫 You should be able to access your local install of Open Food Facts at http://productopener.localhost"
	@echo "🥫 You have around 100 test products. Please run 'make import_prod_data' if you want a full production dump (~2M products)."

edit_etc_hosts:
	@grep -qxF -- "${HOSTS}" /etc/hosts || echo "${HOSTS}" >> /etc/hosts

# TODO: Figure out events => actions and implement live reload
# live_reload:
# 	@echo "🥫 Installing when-changed …"
# 	pip3 install when-changed
# 	@echo "🥫 Watching directories for change …"
# 	when-changed -r lib/
# 	when-changed -r . -lib/ -html/ -logs/ -c "make restart_apache"
# 	when-changed . -x lib/ -x html/ -c "make restart_apache"
# 	when-changed -r docker/ docker-compose.yml .env -c "make restart"                                            # restart backend container on compose changes
# 	when-changed -r lib/ -c "make restart_apache"                                  							     # restart Apache on code changes
# 	when-changed -r html/ -r css/ -r scss/ -r icons/ -r Dockerfile Dockerfile.frontend package.json -c "make up" # rebuild containers

#----------------#
# Docker Compose #
#----------------#
up:
	@echo "🥫 Building and starting containers …"
	${DOCKER_COMPOSE} up -d --remove-orphans --build 2>&1

down:
	@echo "🥫 Bringing down containers …"
	${DOCKER_COMPOSE} down

hdown:
	@echo "🥫 Bringing down containers and associated volumes …"
	${DOCKER_COMPOSE} down -v

reset: hdown up

restart:
	@echo "🥫 Restarting frontend & backend containers …"
	${DOCKER_COMPOSE} restart backend frontend

restart_db:
	@echo "🥫 Restarting MongoDB database …"
	${DOCKER_COMPOSE} restart mongodb

status:
	@echo "🥫 Getting container status …"
	${DOCKER_COMPOSE} ps

livecheck:
	@echo "🥫 Running livecheck …"
	docker/docker-livecheck.sh

log:
	@echo "🥫 Reading logs (docker-compose) …"
	${DOCKER_COMPOSE} logs -f backend frontend

tail:
	@echo "🥫 Reading logs (Apache2, Nginx) …"
	tail -f logs/**/*

setup_incron:
	@echo "🥫 Setting up incron jobs defined in conf/incron.conf …"
	${DOCKER_COMPOSE} exec -T backend sh -c "\
		echo 'root' >> /etc/incron.allow && \
		incrontab -u root /opt/product-opener/conf/incron.conf && \
		incrond"

refresh_product_tags:
	@echo "🥫 Refreshing products tags (update MongoDB products_tags collection) …"
	docker cp scripts/refresh_products_tags.js po_mongodb_1:/data/db
	${DOCKER_COMPOSE} exec -T mongodb /bin/sh -c "mongo off /data/db/refresh_products_tags.js"

import_sample_data:
	@echo "🥫 Importing sample data (~100 products) into MongoDB …"
	${DOCKER_COMPOSE} exec --user=www-data backend bash /opt/product-opener/scripts/import_sample_data.sh

import_prod_data:
	@echo "🥫 Importing production data (~2M products) into MongoDB …"
	@echo "🥫 This might take up to 10 mn, so feel free to grab a coffee!"
	@echo "🥫 Downloading full MongoDB dump from production …"
	wget https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.tar.gz
	@echo "🥫 Copying the dump to MongoDB container …"
	docker cp openfoodfacts-mongodbdump.tar.gz po_mongodb_1:/data/db
	@echo "🥫 Restoring the MongoDB dump …"
	${DOCKER_COMPOSE} exec -T mongodb /bin/sh -c "cd /data/db && tar -xzvf openfoodfacts-mongodbdump.tar.gz && mongorestore --batchSize=1 && rm openfoodfacts-mongodbdump.tar.gz"
	rm openfoodfacts-mongodbdump.tar.gz

#------------#
# Production #
#------------#
create_external_volumes:
	@echo "🥫 Creating external volumes (production only) …"
	docker volume create --driver=local -o type=none -o o=bind -o device=${MOUNT_POINT}/data html_data || echo "Docker volume 'html_data' already exist. Skipping."
	docker volume create --driver=local -o type=none -o o=bind -o device=${MOUNT_POINT}/users users || echo "Docker volume 'users' already exist. Skipping."
	docker volume create --driver=local -o type=none -o o=bind -o device=${MOUNT_POINT}/products products || echo "Docker volume 'products' already exist. Skipping."
	docker volume create --driver=local -o type=none -o o=bind -o device=${MOUNT_POINT}/product_images product_images || echo "Docker volume 'product_images' already exist. Skipping."
	docker volume create --driver=local -o type=none -o o=bind -o device=${MOUNT_POINT}/orgs orgs || echo "Docker volume 'orgs' already exist. Skipping."

#---------#
# Cleanup #
#---------#
prune:
	@echo "🥫 Pruning unused Docker artifacts (save space) …"
	docker system prune -af

prune_cache:
	@echo "🥫 Pruning Docker builder cache …"
	docker builder prune -f

clean: goodbye hdown prune prune_cache
	rm html/images/products
	rm -rf node_modules/
	rm -rf html/data/i18n/
	rm -rf html/{css,js}/dist/
	rm -rf tmp/
	rm -rf logs/
