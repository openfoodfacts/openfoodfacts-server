#!/usr/bin/make

NAME = "ProductOpener"
ENV_FILE ?= .env
HOSTS=127.0.0.1 world.productopener.localhost fr.productopener.localhost static.productopener.localhost ssl-api.productopener.localhost fr-en.productopener.localhost

.DEFAULT_GOAL := dev

hello:
	@echo "🥫 Welcome to the Open Food Facts dev environment setup !"
	@echo "🥫 Note that the first installation might take a while to run, depending on your machine specs."
	@echo "🥫 Typical installation time on 8GB RAM, 4-core CPU, and decent network bandwith is about 10mn."
	@echo "🥫 Thanks for contributing to OpenFoodFacts !"
	@echo

dev: hello up import_sample_data
	@echo "🥫 You should be able to access your local install of Open Food Facts at http://productopener.localhost"
	@echo "🥫 You have around 100 test products. Please run 'make import_prod_data' if you want a full production dump (~2M products)."

edit_etc_hosts:
	@grep -qxF -- "${HOSTS}" /etc/hosts || echo "${HOSTS}" >> /etc/hosts

#-------#
# Admin #
#-------#
up:
	@echo "🥫 Building and starting ProductOpener containers ..."
	docker-compose --env-file=${ENV_FILE} up -d --remove-orphans --build 2>&1

down:
	@echo "🥫 Bringing down ProductOpener containers and associated volumes ..."
	docker-compose --env-file=${ENV_FILE} down -v

restart:
	@echo "🥫 Restarting ProductOpener frontend & backend containers ..."
	docker-compose --env-file=${ENV_FILE} restart backend frontend

log:
	@echo "🥫 Reading ProductOpener logs (docker-compose) ..."
	docker-compose --env-file=${ENV_FILE} logs -f

tail:
	@echo "🥫 Reading ProductOpener logs (Apache2, Nginx) ..."
	tail -f logs/**/*

status:
	@echo "🥫 Getting ProductOpener container status ..."
	docker-compose --env-file=${ENV_FILE} ps

prune:
	@echo "🥫 Pruning unused Docker artifacts (save space) ..."
	docker system prune -af

prune_cache:
	@echo "🥫 Pruning Docker builder cache ..."
	docker builder prune -f

# TODO: Figure out events => actions and implement live reload
# live_reload:
# @echo "🥫 Installing when-changed ..."
# pip3 install when-changed
# @echo "🥫 Watching directories for change ..."
# when-changed -r lib/
# when-changed -r . -lib/ -html/ -logs/ -c "make restart_apache"
# when-changed . -x lib/ -x html/ -c "make restart_apache"
# when-changed -r docker/ docker-compose.yml .env -c "make restart"                                            # restart backend container on compose changes
# when-changed -r lib/ -c "make restart_apache"                                  							   # restart Apache on code changes
# when-changed -r html/ -r css/ -r scss/ -r icons/ -r Dockerfile Dockerfile.frontend package.json -c "make up" # rebuild containers

#------------------#
# Backend commands #
#------------------#
restart_apache:
	@echo "🥫 Restarting Apache ..."
	docker-compose --env-file=${ENV_FILE} exec backend sh -c "apache2ctl -k restart"

build_lang:
	@echo "🥫 Running scripts/build_lang.pl ..."
	docker-compose --env-file=${ENV_FILE} exec backend sh -c "\
		perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl &&\
		chown -R www-data:www-data /mnt/podata &&\
		chown -R www-data:www-data /opt/product-opener/html/images/products"
	@echo "🥫 Built lang.json files in /mnt/podata/lang"	
	@echo "🥫 Built Lang.${PRODUCT_OPENER_DOMAIN}.sto in /mnt/podata"
	@echo "🥫 Changed ownership of /mnt/podata and /opt/product-opener/html/images/products to www-data user"

setup_incron:
	@echo "🥫 Setting up incron jobs defined in conf/incron.conf ..."
	docker-compose --env-file=${ENV_FILE} exec backend sh -c "\
		echo 'root' >> /etc/incron.allow && \
		incrontab -u root /opt/product-opener/conf/incron.conf && \
		incrond"
	@echo "🥫 Incron jobs have been setup ..."

#---------#
# Imports #
#---------#
import_sample_data:
	@echo "🥫 Importing sample data (~100 products) into MongoDB ..."
	docker-compose --env-file=${ENV_FILE} exec backend bash /opt/product-opener/scripts/import_sample_data.sh

import_prod_data:
	@echo "🥫 Importing production data (~2M products) into MongoDB ..."
	@echo "🥫 This might take up to 10 mn, so feel free to grab a coffee !"
	echo "🥫 Downloading the full MongoDB dump ..."
	wget https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.tar.gz
	echo "🥫 Copying the dump to MongoDB container ..."
	docker cp openfoodfacts-mongodbdump.tar.gz po_mongodb_1:/data/db
	echo "🥫 Restoring the MongoDB dump ..."
	docker-compose --env-file=${ENV_FILE} exec mongodb /bin/sh -c "cd /data/db && tar -xzvf openfoodfacts-mongodbdump.tar.gz && mongorestore"
	rm openfoodfacts-mongodbdump.tar.gz

#-----------#
# Utilities #
#-----------#
info:
	@echo "${NAME} version: ${VERSION}"

clean: down prune prune_cache
	rm -rf node_modules/
	rm -rf html/data/i18n/
	rm -rf html/images/products/
	rm -rf html/{css,js}/dist/
	rm -rf tmp/
	rm -rf logs/
