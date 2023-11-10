#!/usr/bin/make

ifeq ($(findstring cmd.exe,$(SHELL)),cmd.exe)
    $(error "We do not suppport using cmd.exe on Windows, please run in a 'git bash' console")
endif


# use bash everywhere !
SHELL := /bin/bash
# some vars
ENV_FILE ?= .env
NAME = "ProductOpener"
MOUNT_POINT ?= /mnt
DOCKER_LOCAL_DATA ?= /srv/off/docker_data
OS := $(shell uname)

# mount point for shared data (default to the one on staging)
NFS_VOLUMES_ADDRESS ?= 10.0.0.3
NFS_VOLUMES_BASE_PATH ?= /rpool/off/clones

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
UID ?= $(shell id -u)
export USER_UID:=${UID}
ifeq ($(OS), Darwin)
  export CPU_COUNT=$(shell sysctl -n hw.logicalcpu || echo 1)
else
  export CPU_COUNT=$(shell nproc || echo 1)
endif

# tell gitbash not to complete path
export MSYS_NO_PATHCONV=1

# load env variables
# also takes into account envrc (direnv file)
ifneq (,$(wildcard ./${ENV_FILE}))
    -include ${ENV_FILE}
    -include .envrc
    export
endif

ifneq (${EXTRA_ENV_FILE},'')
    -include ${EXTRA_ENV_FILE}
    export
endif


HOSTS=127.0.0.1 world.productopener.localhost fr.productopener.localhost static.productopener.localhost ssl-api.productopener.localhost fr-en.productopener.localhost
# commands aliases
DOCKER_COMPOSE=docker-compose --env-file=${ENV_FILE} ${LOAD_EXTRA_ENV_FILE}
# we run tests in a specific project name to be separated from dev instances
# we also publish mongodb on a separate port to avoid conflicts
# we also enable the possibility to fake services in po_test_runner
DOCKER_COMPOSE_TEST=ROBOTOFF_URL="http://backend:8881/" GOOGLE_CLOUD_VISION_API_URL="http://backend:8881/" COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}_test PO_COMMON_PREFIX=test_ MONGO_EXPOSE_PORT=27027 docker-compose --env-file=${ENV_FILE}

.DEFAULT_GOAL := usage

# this target is always to build, see https://www.gnu.org/software/make/manual/html_node/Force-Targets.html
_FORCE:

#------#
# Info #
#------#
info:
	@echo "${NAME} version: ${VERSION}"

usage:
	@echo "🥫 Welcome to the Open Food Facts project"
	@echo "🥫 See available commands at docker/README.md"
	@echo "🥫 or https://openfoodfacts.github.io/openfoodfacts-server/dev/ref-docker-commands/"

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

codecov_prepare:
	@echo "🥫 Preparing to run code coverage…"
	mkdir -p cover_db
	${DOCKER_COMPOSE_TEST} run --rm backend cover -delete
	mkdir -p cover_db

codecov:
	@echo "🥫 running cover to generate a report usable by codecov …"
	${DOCKER_COMPOSE_TEST} run --rm backend cover -report codecovbash

coverage_txt:
	@echo "🥫 running cover to generate text report …"
	${DOCKER_COMPOSE_TEST} run --rm backend cover

#----------#
# Services #
#----------#
build_lang:
	@echo "🥫 Rebuild language"
    # Run build_lang.pl
    # Languages may build taxonomies on-the-fly so include GITHUB_TOKEN so results can be cached
	${DOCKER_COMPOSE} run --rm -e GITHUB_TOKEN=${GITHUB_TOKEN} backend perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl

build_lang_test:
# Run build_lang.pl in test env
	${DOCKER_COMPOSE_TEST} run --rm -e GITHUB_TOKEN=${GITHUB_TOKEN} backend perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl

# use this in dev if you messed up with permissions or user uid/gid
reset_owner:
	@echo "🥫 reset owner"
	${DOCKER_COMPOSE_TEST} run --rm --no-deps --user root backend chown www-data:www-data -R /opt/product-opener/ /mnt/podata /var/log/apache2 /var/log/httpd  || true
	${DOCKER_COMPOSE_TEST} run --rm --no-deps --user root frontend chown www-data:www-data -R /opt/product-opener/html/images/icons/dist /opt/product-opener/html/js/dist /opt/product-opener/html/css/dist

init_backend: build_lang build_taxonomies

create_mongodb_indexes:
	@echo "🥫 Creating MongoDB indexes …"
	docker cp conf/mongodb/create_indexes.js $(shell docker-compose ps -q mongodb):/data/db
	${DOCKER_COMPOSE} exec -T mongodb //bin/sh -c "mongo off /data/db/create_indexes.js"

refresh_product_tags:
	@echo "🥫 Refreshing product data cached in Postgres …"
	${DOCKER_COMPOSE} run --rm backend perl /opt/product-opener/scripts/refresh_postgres.pl ${from}

import_sample_data:
	@echo "🥫 Importing sample data (~200 products) into MongoDB …"
	${DOCKER_COMPOSE} run --rm backend bash /opt/product-opener/scripts/import_sample_data.sh

import_more_sample_data:
	@echo "🥫 Importing sample data (~2000 products) into MongoDB …"
	${DOCKER_COMPOSE} run --rm backend bash /opt/product-opener/scripts/import_more_sample_data.sh

# this command is used to import data on the mongodb used on staging environment
import_prod_data:
	@echo "🥫 Importing production data (~2M products) into MongoDB …"
	@echo "🥫 This might take up to 10 mn, so feel free to grab a coffee!"
	@echo "🥫 Removing old archive in case you have one"
	( rm -f ./html/data/openfoodfacts-mongodbdump.gz || true ) && ( rm -f ./html/data/gz-sha256sum || true )
	@echo "🥫 Downloading full MongoDB dump from production …"
	wget --no-verbose https://static.openfoodfacts.org/data/openfoodfacts-mongodbdump.gz -P ./html/data
	wget --no-verbose https://static.openfoodfacts.org/data/gz-sha256sum -P ./html/data
	cd ./html/data && sha256sum --check gz-sha256sum
	@echo "🥫 Restoring the MongoDB dump …"
	${DOCKER_COMPOSE} exec -T mongodb //bin/sh -c "cd /data/db && mongorestore --quiet --drop --gzip --archive=/import/openfoodfacts-mongodbdump.gz"
	rm html/data/openfoodfacts-mongodbdump.gz && rm html/data/gz-sha256sum

#--------#
# Checks #
#--------#

front_npm_update:
	COMPOSE_PATH_SEPARATOR=";" COMPOSE_FILE="docker-compose.yml;docker/dev.yml;docker/jslint.yml" docker-compose run --rm dynamicfront  npm update

front_lint:
	COMPOSE_PATH_SEPARATOR=";" COMPOSE_FILE="docker-compose.yml;docker/dev.yml;docker/jslint.yml" docker-compose run --rm dynamicfront  npm run lint

front_build:
	COMPOSE_PATH_SEPARATOR=";" COMPOSE_FILE="docker-compose.yml;docker/dev.yml;docker/jslint.yml" docker-compose run --rm dynamicfront  npm run build


checks: front_build front_lint check_perltidy check_perl_fast check_critic

lint: lint_perltidy

tests: build_lang_test unit_test integration_test

# add COVER_OPTS='-e HARNESS_PERL_SWITCHES="-MDevel::Cover"' if you want to trigger code coverage report generation
unit_test:
	@echo "🥫 Running unit tests …"
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb
	${DOCKER_COMPOSE_TEST} run ${COVER_OPTS} -T --rm backend prove -l --jobs ${CPU_COUNT} -r tests/unit
	${DOCKER_COMPOSE_TEST} stop
	@echo "🥫 unit tests success"

integration_test:
	@echo "🥫 Running integration tests …"
# we launch the server and run tests within same container
# we also need dynamicfront for some assets to exists
# this is the place where variables are important
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb backend dynamicfront incron minion
# note: we need the -T option for ci (non tty environment)
	${DOCKER_COMPOSE_TEST} exec ${COVER_OPTS}  -T backend prove -l -r tests/integration
	${DOCKER_COMPOSE_TEST} stop
	@echo "🥫 integration tests success"

# stop all tests dockers
test-stop:
	@echo "🥫 Stopping test dockers"
	${DOCKER_COMPOSE_TEST} stop

# usage:  make test-unit test=test-name.t
# you can add args= to pass options, like args="-d" to debug
test-unit: guard-test
	@echo "🥫 Running test: 'tests/unit/${test}' …"
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb
	${DOCKER_COMPOSE_TEST} run --rm backend perl ${args} tests/unit/${test}

# usage:  make test-int test=test-name.t
# to update expected results: make test-int test="test-name.t --update-expected-results"
test-int: guard-test # usage: make test-int test=test-file.t
	@echo "🥫 Running test: 'tests/integration/${test}' …"
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb backend dynamicfront incron minion
	${DOCKER_COMPOSE_TEST} exec backend perl ${args} tests/integration/${test}
# better shutdown, for if we do a modification of the code, we need a restart
	${DOCKER_COMPOSE_TEST} stop backend

# stop all docker tests containers
stop_tests:
	${DOCKER_COMPOSE_TEST} stop

# clean tests, remove containers and volume (useful if you changed env variables, etc.)
clean_tests:
	${DOCKER_COMPOSE_TEST} down -v --remove-orphans

update_tests_results: build_lang_test
	@echo "🥫 Updated expected test results with actuals for easy Git diff"
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb backend dynamicfront incron
	${DOCKER_COMPOSE_TEST} run --no-deps --rm -e GITHUB_TOKEN=${GITHUB_TOKEN} backend /opt/product-opener/scripts/build_tags_taxonomy.pl ${name}
	${DOCKER_COMPOSE_TEST} run --rm backend perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl
	${DOCKER_COMPOSE_TEST} exec -T -w /opt/product-opener/tests backend bash update_tests_results.sh
	${DOCKER_COMPOSE_TEST} stop

bash:
	@echo "🥫 Open a bash shell in the test container"
	${DOCKER_COMPOSE_TEST} run --rm -w /opt/product-opener backend bash

# check perl compiles, (pattern rule) / but only for newer files
%.pm %.pl: _FORCE
	@if [[ -f $@ ]]; then perl -c -CS -Ilib $@; else true; fi


# TO_CHECK look at changed files (compared to main) with extensions .pl, .pm, .t
# filter out obsolete scripts
# the ls at the end is to avoid removed files.
# the first commad is to check we have git (to avoid trying to run this line inside the container on check_perl*)
# We have to finally filter out "." as this will the output if we have no file
TO_CHECK=$(shell [ -x "`which git 2>/dev/null`" ] && git diff origin/main --name-only | grep  '.*\.\(pl\|pm\|t\)$$' | grep -v "scripts/obsolete" | xargs ls -d 2>/dev/null | grep -v "^.$$" )

check_perl_fast:
	@echo "🥫 Checking ${TO_CHECK}"
	test -z "${TO_CHECK}" || ${DOCKER_COMPOSE} run --rm backend make -j ${CPU_COUNT} ${TO_CHECK}

check_translations:
	@echo "🥫 Checking translations"
	${DOCKER_COMPOSE} run --rm backend scripts/check-translations.sh

# check all perl files compile (takes time, but needed to check a function rename did not break another module !)
check_perl:
	@echo "🥫 Checking all perl files"
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb
	${DOCKER_COMPOSE_TEST} run --rm --no-deps backend make -j ${CPU_COUNT} cgi/*.pl scripts/*.pl lib/*.pl lib/ProductOpener/*.pm
	${DOCKER_COMPOSE_TEST} stop


# check with perltidy
# we exclude files that are in .perltidy_excludes
TO_TIDY_CHECK = $(shell echo ${TO_CHECK}| tr " " "\n" | grep -vFf .perltidy_excludes)
check_perltidy:
	@echo "🥫 Checking with perltidy ${TO_TIDY_CHECK}"
	test -z "${TO_TIDY_CHECK}" || ${DOCKER_COMPOSE} run --rm --no-deps backend perltidy --assert-tidy -opath=/tmp/ --standard-error-output ${TO_TIDY_CHECK}

# same as check_perltidy, but this time applying changes
lint_perltidy:
	@echo "🥫 Linting with perltidy ${TO_TIDY_CHECK}"
	test -z "${TO_TIDY_CHECK}" || ${DOCKER_COMPOSE} run --rm --no-deps backend perltidy --standard-error-output -b -bext=/ ${TO_TIDY_CHECK}


#Checking with Perl::Critic
# adding an echo of search.pl in case no files are edited
check_critic:
	@echo "🥫 Checking with perlcritic"
	test -z "${TO_CHECK}" || ${DOCKER_COMPOSE} run --rm --no-deps backend perlcritic ${TO_CHECK}


check_openapi_v2:
	docker run --rm \
		-v ${PWD}:/local openapitools/openapi-generator-cli validate --recommend \
		-i /local/docs/api/ref/api.yml

check_openapi_v3:
	docker run --rm \
		-v ${PWD}:/local openapitools/openapi-generator-cli validate --recommend \
		-i /local/docs/api/ref/api-v3.yml

check_openapi: check_openapi_v2 check_openapi_v3

#-------------#
# Compilation #
#-------------#

build_taxonomies: build_lang # build_lang generates the nutrient_level taxonomy source file
	@echo "🥫 build taxonomies"
    # GITHUB_TOKEN might be empty, but if it's a valid token it enables pushing taxonomies to build cache repository
	${DOCKER_COMPOSE} run --no-deps --rm -e GITHUB_TOKEN=${GITHUB_TOKEN} backend /opt/product-opener/scripts/build_tags_taxonomy.pl ${name}

rebuild_taxonomies: build_taxonomies

#------------#
# Production #
#------------#
create_external_volumes:
	@echo "🥫 Creating external volumes (production only) …"
# zfs clones hosted on Ovh3 as NFS
	docker volume create --driver=local --opt type=nfs --opt o=addr=${NFS_VOLUMES_ADDRESS},rw,nolock --opt device=:${NFS_VOLUMES_BASE_PATH}/users ${COMPOSE_PROJECT_NAME}_users
	docker volume create --driver=local --opt type=nfs --opt o=addr=${NFS_VOLUMES_ADDRESS},rw,nolock --opt device=:${NFS_VOLUMES_BASE_PATH}/products ${COMPOSE_PROJECT_NAME}_products
	docker volume create --driver=local --opt type=nfs --opt o=addr=${NFS_VOLUMES_ADDRESS},rw,nolock --opt device=:${NFS_VOLUMES_BASE_PATH}/images/products ${COMPOSE_PROJECT_NAME}_product_images
	docker volume create --driver=local --opt type=nfs --opt o=addr=${NFS_VOLUMES_ADDRESS},rw,nolock --opt device=:${NFS_VOLUMES_BASE_PATH}/orgs ${COMPOSE_PROJECT_NAME}_orgs
# local data
	docker volume create --driver=local -o type=none -o o=bind -o device=${DOCKER_LOCAL_DATA}/data ${COMPOSE_PROJECT_NAME}_html_data
	docker volume create --driver=local -o type=none -o o=bind -o device=${DOCKER_LOCAL_DATA}/podata ${COMPOSE_PROJECT_NAME}_podata

create_external_networks:
	@echo "🥫 Creating external networks (production only) …"
	docker network create --driver=bridge --subnet="172.30.0.0/16" ${COMPOSE_PROJECT_NAME}_webnet \
	|| echo "network already exists"


update_all_packager_codes:
	@echo "🥫 Dowloading packager codes (production only) …"
	${DOCKER_COMPOSE} run --rm backend perl /opt/product-opener/scripts/packager_codes/update_all_packager_codes.sh

#---------#
# Cleanup #
#---------#
prune:
	@echo "🥫 Pruning unused Docker artifacts (save space) …"
	docker system prune -af

prune_cache:
	@echo "🥫 Pruning Docker builder cache …"
	docker builder prune -f

clean_folders: clean_logs
	( rm html/images/products || true )
	( rm -rf node_modules/ || true )
	( rm -rf html/data/i18n/ || true )
	( rm -rf html/{css,js}/dist/ || true )
	( rm -rf tmp/ || true )

clean_logs:
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

