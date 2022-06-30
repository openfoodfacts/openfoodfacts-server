#!/usr/bin/make

NAME = "ProductOpener"
ENV_FILE ?= .env
MOUNT_POINT ?= /mnt
DOCKER_LOCAL_DATA ?= /srv/off/docker_data
HOSTS=127.0.0.1 world.productopener.localhost fr.productopener.localhost static.productopener.localhost ssl-api.productopener.localhost fr-en.productopener.localhost
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
UID ?= $(shell id -u)
export USER_UID:=${UID}

export CPU_COUNT=$(shell nproc || echo 1)


DOCKER_COMPOSE=docker-compose --env-file=${ENV_FILE}
# we run tests in a specific project name to be separated from dev instances
DOCKER_COMPOSE_TEST=COMPOSE_PROJECT_NAME=po_test PO_COMMON_PREFIX=test_ docker-compose --env-file=${ENV_FILE}

.DEFAULT_GOAL := dev

# this target is always to build, see https://www.gnu.org/software/make/manual/html_node/Force-Targets.html
_FORCE:

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
dev: hello build init_backend _up import_sample_data create_mongodb_indexes refresh_product_tags
	@echo "🥫 You should be able to access your local install of Open Food Facts at http://world.openfoodfacts.localhost/"
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

build:
	@echo "🥫 Building containers …"
	${DOCKER_COMPOSE} build 2>&1

# this is needed for CI
build_backend:
	@echo "🥫 Building backend container …"
	${DOCKER_COMPOSE} build backend 2>&1

_up:
	@echo "🥫 Starting containers …"
	${DOCKER_COMPOSE} up -d 2>&1
	@echo "🥫 started service at http://openfoodfacts.localhost"

up: build _up

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
	@echo "🥫  started service at http://openfoodfacts.localhost"

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
	${DOCKER_COMPOSE} logs -f

tail:
	@echo "🥫 Reading logs (Apache2, Nginx) …"
	tail -f logs/**/*


#----------#
# Services #
#----------#
build_lang:
	@echo "🥫 Rebuild language"
# Run build_lang.pl
	${DOCKER_COMPOSE} run --rm backend perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl

build_lang_test:
# Run build_lang.pl in test env
	${DOCKER_COMPOSE_TEST} run --rm backend perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl

# use this in dev if you messed up with permissions or user uid/gid
reset_owner:
	@echo "🥫 reset owner"
	${DOCKER_COMPOSE} run --rm --no-deps --user root backend chown www-data:www-data -R /opt/product-opener/ /mnt/podata /var/log/apache2 /var/log/httpd  || true
	${DOCKER_COMPOSE} run --rm --no-deps --user root frontend chown www-data:www-data -R /opt/product-opener/html/images/icons/dist /opt/product-opener/html/js/dist /opt/product-opener/html/css/dist

init_backend: build_lang

create_mongodb_indexes:
	@echo "🥫 Creating MongoDB indexes …"
	docker cp conf/mongodb/create_indexes.js $(shell docker-compose ps -q mongodb):/data/db
	${DOCKER_COMPOSE} exec -T mongodb //bin/sh -c "mongo off /data/db/create_indexes.js"

refresh_product_tags:
	@echo "🥫 Refreshing products tags (update MongoDB products_tags collection) …"
# get id for mongodb container
	docker cp scripts/refresh_products_tags.js $(shell docker-compose ps -q mongodb):/data/db
	${DOCKER_COMPOSE} exec -T mongodb //bin/sh -c "mongo off /data/db/refresh_products_tags.js"

import_sample_data:
	@echo "🥫 Importing sample data (~200 products) into MongoDB …"
	${DOCKER_COMPOSE} run --rm backend bash /opt/product-opener/scripts/import_sample_data.sh

import_more_sample_data:
	@echo "🥫 Importing sample data (~2000 products) into MongoDB …"
	${DOCKER_COMPOSE} run --rm backend bash /opt/product-opener/scripts/import_more_sample_data.sh

import_prod_data:
	@echo "🥫 Importing production data (~2M products) into MongoDB …"
	@echo "🥫 This might take up to 10 mn, so feel free to grab a coffee!"
	@echo "🥫 Removing old archive in case you have one"
	( rm -f openfoodfacts-mongodbdump.tar.gz || true )
	@echo "🥫 Downloading full MongoDB dump from production …"
	wget --no-verbose https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.tar.gz
	@echo "🥫 Copying the dump to MongoDB container …"
	docker cp openfoodfacts-mongodbdump.tar.gz $(shell docker-compose ps -q mongodb):/data/db
	@echo "🥫 Restoring the MongoDB dump …"
	${DOCKER_COMPOSE} exec -T mongodb //bin/sh -c "cd /data/db && tar -xzvf openfoodfacts-mongodbdump.tar.gz && mongorestore --batchSize=1 && rm openfoodfacts-mongodbdump.tar.gz"
	rm openfoodfacts-mongodbdump.tar.gz

#--------#
# Checks #
#--------#

front_lint:
	COMPOSE_PATH_SEPARATOR=";" COMPOSE_FILE="docker-compose.yml;docker/dev.yml;docker/jslint.yml" docker-compose run --rm dynamicfront  npm run lint

front_build:
	COMPOSE_PATH_SEPARATOR=";" COMPOSE_FILE="docker-compose.yml;docker/dev.yml;docker/jslint.yml" docker-compose run --rm dynamicfront  npm run build

checks: front_build front_lint check_perl_fast


tests: build_lang_test
	@echo "🥫 Running tests …"
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb
	${DOCKER_COMPOSE_TEST} run --rm backend prove -l --jobs ${CPU_COUNT}
	${DOCKER_COMPOSE_TEST} stop
	@echo "🥫 test success"

test-one: guard-test # usage: make test-one test=t/test-file.t
	@echo "🥫 Running test: '${test}' …"
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb
	${DOCKER_COMPOSE_TEST} run --rm backend perl ${test}

# check perl compiles, (pattern rule) / but only for newer files
%.pm %.pl: _FORCE
	if [ -f $@ ]; then perl -c -CS -Ilib $@; else true; fi

# check all modified (compared to main) perl file compiles
TO_CHECK=$(shell git diff main --name-only | grep  '.*\.\(pl\|pm\)$$')
check_perl_fast:
	@echo "🥫checking ${TO_CHECK}"
	${DOCKER_COMPOSE} run --rm backend make -j ${CPU_COUNT} ${TO_CHECK}

check_translations:
	@echo "🥫checking translations"
	${DOCKER_COMPOSE} run --rm backend scripts/check-translations.sh

# check all perl files compile (takes time, but needed to check a function rename did not break another module !)
check_perl:
	@echo "🥫checking all perl files"
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb
	${DOCKER_COMPOSE_TEST} run --rm --no-deps backend make -j ${CPU_COUNT} cgi/*.pl scripts/*.pl lib/*.pl lib/ProductOpener/*.pm
	${DOCKER_COMPOSE_TEST} stop

#-------------#
# Compilation #
#-------------#

build_taxonomies:
	@echo "🥫 build taxonomies on ${CPU_COUNT} procs"
	${DOCKER_COMPOSE} run --no-deps --rm backend make -C taxonomies -j ${CPU_COUNT}

rebuild_taxonomies:
	@echo "🥫 re-build taxonomies on ${CPU_COUNT} procs"
	${DOCKER_COMPOSE} run --rm backend make -C taxonomies all_taxonomies -j ${CPU_COUNT}

#------------#
# Production #
#------------#
create_external_volumes:
	@echo "🥫 Creating external volumes (production only) …"
# zfs replications
	docker volume create --driver=local -o type=none -o o=bind -o device=${MOUNT_POINT}/data html_data
	docker volume create --driver=local -o type=none -o o=bind -o device=${MOUNT_POINT}/users users
	docker volume create --driver=local -o type=none -o o=bind -o device=${MOUNT_POINT}/products products
	docker volume create --driver=local -o type=none -o o=bind -o device=${MOUNT_POINT}/product_images product_images
	docker volume create --driver=local -o type=none -o o=bind -o device=${MOUNT_POINT}/orgs orgs
# local data
	docker volume create --driver=local -o type=none -o o=bind -o device=${DOCKER_LOCAL_DATA}/podata podata

#---------#
# Cleanup #
#---------#
prune:
	@echo "🥫 Pruning unused Docker artifacts (save space) …"
	docker system prune -af

prune_cache:
	@echo "🥫 Pruning Docker builder cache …"
	docker builder prune -f

clean_folders:
	( rm html/images/products || true )
	( rm -rf node_modules/ || true )
	( rm -rf html/data/i18n/ || true )
	( rm -rf html/{css,js}/dist/ || true )
	( rm -rf tmp/ || true )
	( rm -f logs/* logs/apache2/* logs/nginx/* || true )

clean: goodbye hdown prune prune_cache clean_folders

#-----------#
# Utilities #
#-----------#

guard-%: # guard clause for targets that require an environment variable (usually used as an argument)
	@ if [ "${${*}}" = "" ]; then \
   		echo "Environment variable '$*' is not set"; \
   		exit 1; \
	fi;
