#!/usr/bin/make

ifeq ($(findstring cmd.exe,$(SHELL)),cmd.exe)
    $(error "We do not suppport using cmd.exe on Windows, please run in a 'git bash' console")
endif


# use bash everywhere !
SHELL := $(shell which bash)
# some vars
ENV_FILE ?= .env
NAME = "ProductOpener"
VERSION = $(shell cat version.txt)
MOUNT_POINT ?= /mnt
DOCKER_LOCAL_DATA_DEFAULT = /srv/off/docker_data
DOCKER_LOCAL_DATA ?= $(DOCKER_LOCAL_DATA_DEFAULT)
OS := $(shell uname)

# mount point for shared data (default to the one on staging)
NFS_VOLUMES_ADDRESS ?= 10.0.0.3
NFS_VOLUMES_BASE_PATH ?= /rpool/staging-clones

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
DOCKER_COMPOSE=docker compose --env-file=${ENV_FILE} ${LOAD_EXTRA_ENV_FILE}
# docker command that do not need the shared network
DOCKER_COMPOSE_BUILD=COMPOSE_FILE="${COMPOSE_FILE_BUILD}" ${DOCKER_COMPOSE}
# we run tests in a specific project name to be separated from dev instances
# Also we merge the compose files of dependencies right in with COMPOSE_FILE,
# so we are isolated and don't need an external network
# We keep web-default for web contents
# we also publish mongodb on a separate port to avoid conflicts
# we also enable the possibility to fake services in po_test_runner
DOCKER_COMPOSE_TEST=WEB_RESOURCES_PATH=./web-default ROBOTOFF_URL="http://backend:8881/" \
	GOOGLE_CLOUD_VISION_API_URL="http://backend:8881/" \
	ODOO_CRM_URL="" \
	MONGO_EXPOSE_PORT=27027 MONGODB_CACHE_SIZE=4 \
	COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}_test \
	COMPOSE_FILE="${COMPOSE_FILE_BUILD};${DEPS_DIR}/openfoodfacts-shared-services/docker-compose.yml" \
	PO_COMMON_PREFIX=test_  \
	docker compose --env-file=${ENV_FILE}
# Enable Redis only for integration tests
DOCKER_COMPOSE_INT_TEST=REDIS_URL="redis:6379" ${DOCKER_COMPOSE_TEST}
TEST_CMD ?= yath test -PProductOpener::LoadData

# Space delimited list of dependant projects
DEPS=openfoodfacts-shared-services
# Set the DEPS_DIR if it hasn't been set already
ifeq (${DEPS_DIR},)
	export DEPS_DIR=${PWD}/deps
endif

.DEFAULT_GOAL := usage

# this target is always to build, see https://www.gnu.org/software/make/manual/html_node/Force-Targets.html
_FORCE:

#------#
# Info #
#------#
info:
	@echo "${NAME} version: v${VERSION}"

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

#-------#
# CI    #
#-------#
dev_no_build: hello init_backend _up import_sample_data create_mongodb_indexes refresh_product_tags
	@echo "🥫 You should be able to access your local install of Open Food Facts at http://world.openfoodfacts.localhost/"
	@echo "🥫 You have around 100 test products. Please run 'make import_prod_data' if you want a full production dump (~2M products)."

edit_etc_hosts:
	@grep -qxF -- "${HOSTS}" /etc/hosts || echo "${HOSTS}" >> /etc/hosts

create_folders: clone_deps
# create some folders to avoid having them owned by root (when created by docker compose)
	@echo "🥫 Creating folders before docker compose use them."
	mkdir -p logs/apache2 logs/nginx debug html/data sftp || ( whoami; ls -l . ; false )

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

# args variable may be use to eg. "--progress plain" option and keep logs on a failing build
build:
	@echo "🥫 Building containers …"
	${DOCKER_COMPOSE_BUILD} build ${args} ${container} 2>&1

_up:run_deps
	@echo "🥫 Starting containers …"
	${DOCKER_COMPOSE} up -d 2>&1
	@echo "🥫 started service at http://openfoodfacts.localhost"

up: build create_folders _up

# Used by staging so that shared services are not created
# Shared services are started by the github workflow of openfoodfacts-shared-services
prod_up: build create_folders
	@echo "🥫 Starting containers …"
	${DOCKER_COMPOSE} up -d 2>&1

down:
	@echo "🥫 Bringing down containers …"
	${DOCKER_COMPOSE} down

# Note: we use it in deploy, so we must not use --remove-orphans as it would remove shared-net services
hdown:
	@echo "🥫 Bringing down containers and associated volumes …"
	${DOCKER_COMPOSE} down -v ${args}

reset: hdown up

restart:run_deps
	@echo "🥫 Restarting frontend & backend containers …"
	${DOCKER_COMPOSE} restart backend frontend
	@echo "🥫  started service at http://openfoodfacts.localhost"

status:run_deps
	@echo "🥫 Getting container status …"
	${DOCKER_COMPOSE} ps

livecheck:
	@echo "🥫 Running livecheck …"
	docker/docker-livecheck.sh

log:
	@echo "🥫 Reading logs (docker compose) …"
	${DOCKER_COMPOSE} logs -f

tail:
	@echo "🥫 Reading logs (Apache2, Nginx) …"
	tail -f logs/**/*

codecov_prepare: create_folders
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
build_lang: create_folders
	@echo "🥫 Rebuild language"
    # Run build_lang.pl
    # Languages may build taxonomies on-the-fly so include GITHUB_TOKEN so results can be cached
	${DOCKER_COMPOSE_BUILD} run --rm -e GITHUB_TOKEN=${GITHUB_TOKEN} backend perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl

build_lang_test: create_folders
# Run build_lang.pl in test env
	${DOCKER_COMPOSE_TEST} run --rm -e GITHUB_TOKEN=${GITHUB_TOKEN} backend perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl

# use this in dev if you messed up with permissions or user uid/gid
reset_owner:
	@echo "🥫 reset owner"
	${DOCKER_COMPOSE_BUILD} run --rm --no-deps --user root backend chown www-data:www-data -R /opt/product-opener/ /mnt/podata /var/log/apache2 /var/log/httpd  || true
	${DOCKER_COMPOSE_BUILD} run --rm --no-deps --user root frontend chown www-data:www-data -R /opt/product-opener/html/images/icons/dist /opt/product-opener/html/js/dist /opt/product-opener/html/css/dist

init_backend: build_taxonomies build_lang

create_mongodb_indexes:run_deps
	@echo "🥫 Creating MongoDB indexes …"
	${DOCKER_COMPOSE} run --rm backend perl /opt/product-opener/scripts/create_mongodb_indexes.pl

refresh_product_tags: run_deps
	@echo "🥫 Refreshing product data cached in Postgres …"
	${DOCKER_COMPOSE} run --rm backend perl /opt/product-opener/scripts/refresh_postgres.pl ${from}

import_sample_data: run_deps
	@ if [[ "${PRODUCT_OPENER_FLAVOR_SHORT}" = "off" &&  "${PRODUCERS_PLATFORM}" != "1" ]]; then \
   		echo "🥫 Importing sample data (~200 products) into MongoDB …"; \
		${DOCKER_COMPOSE} run --rm -e SKIP_SAMPLE_IMAGES backend bash /opt/product-opener/scripts/import_sample_data.sh; \
	else \
	 	echo "🥫 Not importing sample data into MongoDB (only for po_off project)"; \
	fi
	
import_more_sample_data: run_deps
	@echo "🥫 Importing sample data (~2000 products) into MongoDB …"
	${DOCKER_COMPOSE} run --rm backend bash /opt/product-opener/scripts/import_more_sample_data.sh

refresh_mongodb:run_deps
	@echo "🥫 Refreshing mongoDB from product files …"
	${DOCKER_COMPOSE} run --rm backend perl /opt/product-opener/scripts/update_all_products_from_dir_in_mongodb.pl

# this command is used to import data on the mongodb used on staging environment
import_prod_data: run_deps
	@cd ${DEPS_DIR}/openfoodfacts-shared-services && $(MAKE) import_prod_data

#--------#
# Checks #
#--------#

front_npm_update:
	COMPOSE_PATH_SEPARATOR=";" COMPOSE_FILE="docker-compose.yml;docker/dev.yml;docker/jslint.yml" docker compose run --rm dynamicfront  npm install --save-dev @wesselkuipers/leaflet.markercluster

front_lint:
	COMPOSE_PATH_SEPARATOR=";" COMPOSE_FILE="docker-compose.yml;docker/dev.yml;docker/jslint.yml" docker compose run --rm dynamicfront  npm run lint

front_build:
	COMPOSE_PATH_SEPARATOR=";" COMPOSE_FILE="docker-compose.yml;docker/dev.yml;docker/jslint.yml" docker compose run --rm dynamicfront  npm run build


checks: front_build front_lint check_perltidy check_perl_fast check_critic check_taxonomies

lint: lint_perltidy lint_taxonomies

tests: build_taxonomies_test build_lang_test unit_test integration_test

# add COVER_OPTS='-e HARNESS_PERL_SWITCHES="-MDevel::Cover"' if you want to trigger code coverage report generation
unit_test: create_folders
	@echo "🥫 Running unit tests …"
	mkdir -p tests/unit/outputs/
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb
	${DOCKER_COMPOSE_TEST} run ${COVER_OPTS} -e JUNIT_TEST_FILE="tests/unit/outputs/junit.xml" -e PO_EAGER_LOAD_DATA=1 -T --rm backend yath test --renderer=Formatter --renderer=JUnit --job-count=${CPU_COUNT} -PProductOpener::LoadData  tests/unit
	${DOCKER_COMPOSE_TEST} stop
	@echo "🥫 unit tests success"

integration_test: create_folders
	@echo "🥫 Running integration tests …"
	mkdir -p tests/integration/outputs/
# we launch the server and run tests within same container
# we also need dynamicfront for some assets to exists
# this is the place where variables are important
	${DOCKER_COMPOSE_INT_TEST} up -d memcached postgres mongodb backend dynamicfront incron minion redis frontend
# note: we need the -T option for ci (non tty environment)
	${DOCKER_COMPOSE_INT_TEST} exec ${COVER_OPTS} -e JUNIT_TEST_FILE="tests/integration/outputs/junit.xml" -e PO_EAGER_LOAD_DATA=1 -T backend yath --renderer=Formatter --renderer=JUnit -PProductOpener::LoadData tests/integration
	${DOCKER_COMPOSE_INT_TEST} stop
	@echo "🥫 integration tests success"

# stop all tests dockers
test-stop:
	@echo "🥫 Stopping test dockers"
	${DOCKER_COMPOSE_TEST} stop

# usage:  make test-unit test=test-name.t
# you can use TEST_CMD to change test command, like TEST_CMD="perl -d" to debug a test
# you can also add args= to pass more options to your test command
test-unit: guard-test create_folders
	@echo "🥫 Running test: 'tests/unit/${test}' …"
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb
	${DOCKER_COMPOSE_TEST} run --rm -e PO_EAGER_LOAD_DATA=1 backend ${TEST_CMD} ${args} tests/unit/${test}

# usage:  make test-int test=test-name.t
# to update expected results: make test-int test="test-name.t :: --update-expected-results"
# you can use TEST_CMD to change test command, like TEST_CMD="perl -d" to debug a test
# you can also add args= to pass more options to your test command
test-int: guard-test create_folders
	@echo "🥫 Running test: 'tests/integration/${test}' …"
	${DOCKER_COMPOSE_INT_TEST} up -d memcached postgres mongodb backend dynamicfront incron minion redis frontend
	${DOCKER_COMPOSE_INT_TEST} exec -e PO_EAGER_LOAD_DATA=1 backend ${TEST_CMD} ${args} tests/integration/${test}
# better shutdown, for if we do a modification of the code, we need a restart
	${DOCKER_COMPOSE_INT_TEST} stop backend

# stop all docker tests containers
stop_tests:
	${DOCKER_COMPOSE_TEST} stop

# clean tests, remove containers and volume (useful if you changed env variables, etc.)
clean_tests:
	${DOCKER_COMPOSE_TEST} down -v --remove-orphans

update_tests_results: build_taxonomies_test build_lang_test
	@echo "🥫 Updated expected test results with actuals for easy Git diff"
	${DOCKER_COMPOSE_TEST} up -d memcached postgres mongodb backend dynamicfront incron frontend
	${DOCKER_COMPOSE_TEST} run --no-deps --rm -e GITHUB_TOKEN=${GITHUB_TOKEN} backend /opt/product-opener/scripts/taxonomies/build_tags_taxonomy.pl ${name}
	${DOCKER_COMPOSE_TEST} run --rm backend perl -I/opt/product-opener/lib -I/opt/perl/local/lib/perl5 /opt/product-opener/scripts/build_lang.pl
	${DOCKER_COMPOSE_TEST} exec -T -w /opt/product-opener/tests backend bash update_tests_results.sh
	${DOCKER_COMPOSE_TEST} stop

bash:
	@echo "🥫 Open a bash shell in the backend container"
	${DOCKER_COMPOSE} run --rm -w /opt/product-opener backend bash

bash_test:
	@echo "🥫 Open a bash shell in the test container"
	${DOCKER_COMPOSE_TEST} run --rm -w /opt/product-opener backend bash

# check perl compiles, (pattern rule) / but only for newer files
%.pm %.pl %.t: _FORCE
	@if [[ -f $@ ]]; then PO_NO_LOAD_DATA=1 perl -c -CS -Ilib $@; else true; fi


# TO_CHECK look at changed files (compared to main) with extensions .pl, .pm, .t
# filter out obsolete scripts
# the ls at the end is to avoid removed files.
# the first commad is to check we have git (to avoid trying to run this line inside the container on check_perl*)
# We have to finally filter out "." as this will the output if we have no file
TO_CHECK := $(shell [ -x "`which git 2>/dev/null`" ] && git diff origin/main --name-only | grep  '.*\.\(pl\|pm\|t\)$$' | grep -v "scripts/obsolete" | xargs ls -d 2>/dev/null | grep -v "^.$$" )

check_perl_fast:
	@echo "🥫 Checking ${TO_CHECK}"
	test -z "${TO_CHECK}" || \
	  ${DOCKER_COMPOSE_BUILD} run --rm backend make -j ${CPU_COUNT} ${TO_CHECK} || \
	  ( echo "Perl syntax errors! Look at 'failed--compilation' in above logs" && false )

check_translations:
	@echo "🥫 Checking translations"
	${DOCKER_COMPOSE_BUILD} run --rm backend scripts/check-translations.sh

# check all perl files compile (takes time, but needed to check a function rename did not break another module !)
# IMPORTANT: We exclude some files that are in .check_perl_excludes
check_perl:
	@echo "🥫 Checking all perl files"
	@if grep -P '^\s*$$' .check_perl_excludes; then echo "No blank line accepted in .check_perl_excludes, fix it"; false; fi
	ALL_PERL_FILES=$$(find . -regex ".*\.\(p[lm]\|t\)"|grep -v "/\."|grep -v "/obsolete/"| grep -vFf .check_perl_excludes) ; \
	${DOCKER_COMPOSE_BUILD} run --rm --no-deps backend make -j ${CPU_COUNT} $$ALL_PERL_FILES  || \
	  ( echo "Perl syntax errors! Look at 'failed--compilation' in above logs" && false )

# check with perltidy
# we exclude files that are in .perltidy_excludes
# see %.pl %.pm %.t rule above that compiles files individually
TO_TIDY_CHECK := $(shell echo ${TO_CHECK}| tr " " "\n" | grep -vFf .perltidy_excludes)
check_perltidy:
	@echo "🥫 Checking with perltidy ${TO_TIDY_CHECK}"
	@if grep -P '^\s*$$' .perltidy_excludes; then echo "No blank line accepted in .perltidy_excludes, fix it"; false; fi
	test -z "${TO_TIDY_CHECK}" || ${DOCKER_COMPOSE_BUILD} run --rm --no-deps backend perltidy --assert-tidy -opath=/tmp/ --standard-error-output ${TO_TIDY_CHECK}

# same as check_perltidy, but this time applying changes
lint_perltidy:
	@echo "🥫 Linting with perltidy ${TO_TIDY_CHECK}"
	@if grep -P '^\s*$$' .perltidy_excludes; then echo "No blank line accepted in .perltidy_excludes, fix it"; false; fi
	test -z "${TO_TIDY_CHECK}" || ${DOCKER_COMPOSE_BUILD} run --rm --no-deps backend perltidy --standard-error-output -b -bext=/ ${TO_TIDY_CHECK}


#Checking with Perl::Critic
# adding an echo of search.pl in case no files are edited
# note: to run a complete critic on all files (when you change policy), use:
# find . -regex ".*\.\(p[lM]\|t\)"|grep -v "/\."|grep -v "/obsolete/"|xargs docker compose run --rm --no-deps -T backend perlcritic
check_critic:
	@echo "🥫 Checking with perlcritic"
	test -z "${TO_CHECK}" || ${DOCKER_COMPOSE_BUILD} run --rm --no-deps backend perlcritic ${TO_CHECK}

TAXONOMIES_TO_CHECK := $(shell [ -x "`which git 2>/dev/null`" ] && git diff origin/main --name-only | grep  -P 'taxonomies.*/.*\.txt$$' | grep -v '\.result.txt' | xargs ls -d 2>/dev/null | grep -v "^.$$")

# TODO remove --no-sort as soon as we have sorted taxonomies
check_taxonomies:
	@echo "🥫 Checking taxonomies"
	test -z "${TAXONOMIES_TO_CHECK}" || \
	${DOCKER_COMPOSE_BUILD} run --rm --no-deps backend scripts/taxonomies/lint_taxonomy.pl --verbose --check ${TAXONOMIES_TO_CHECK}

lint_taxonomies:
	@echo "🥫 Linting taxonomies"
	test -z "${TAXONOMIES_TO_CHECK}" || \
	${DOCKER_COMPOSE_BUILD} run --rm --no-deps backend scripts/taxonomies/lint_taxonomy.pl --verbose ${TAXONOMIES_TO_CHECK}


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

build_packager_codes: create_folders
	@echo "🥫 build packager codes"
	${DOCKER_COMPOSE_BUILD} run --no-deps --rm backend /opt/product-opener/scripts/update_packager_codes.pl

build_taxonomies: create_folders
	$(MAKE) MOUNT_FOLDER=build-cache MOUNT_VOLUME=build_cache _bind_local
	@echo "🥫 build taxonomies"
# GITHUB_TOKEN might be empty, but if it's a valid token it enables pushing taxonomies to build cache repository
	${DOCKER_COMPOSE_BUILD} run --no-deps --rm -e GITHUB_TOKEN=${GITHUB_TOKEN} backend /opt/product-opener/scripts/taxonomies/build_tags_taxonomy.pl ${name}

# a version where we force building without using cache
# use it when you are developing in Tags.pm and want to iterate
# at the end, change the $BUILD_TAGS_VERSION in Tags.pm
rebuild_taxonomies:
	$(MAKE) MOUNT_FOLDER=build-cache MOUNT_VOLUME=build_cache _bind_local
	${DOCKER_COMPOSE_BUILD} run --no-deps --rm -e TAXONOMY_NO_GET_FROM_CACHE=1 backend /opt/product-opener/scripts/taxonomies/build_tags_taxonomy.pl ${name}

build_taxonomies_test: create_folders
	$(MAKE) MOUNT_FOLDER=build-cache MOUNT_VOLUME=build_cache PROJECT_SUFFIX=_test _bind_local
	@echo "🥫 build taxonomies"
# GITHUB_TOKEN might be empty, but if it's a valid token it enables pushing taxonomies to build cache repository
	${DOCKER_COMPOSE_TEST} run --no-deps --rm -e GITHUB_TOKEN=${GITHUB_TOKEN} backend /opt/product-opener/scripts/taxonomies/build_tags_taxonomy.pl ${name}


_clean_old_external_volumes:
# THIS IS A MIGRATION STEP, TO BE REMOVED IN THE FUTURE
# we need to stop dockers to remove old volumes
	( docker volume inspect ${COMPOSE_PROJECT_NAME}_{users,orgs,products,product_images} | grep /rpool/off/clones && docker compose down ) || true
	( docker volume inspect ${COMPOSE_PROJECT_NAME}_users|grep /rpool/off/clones && docker volume rm ${COMPOSE_PROJECT_NAME}_users ) || true
	( docker volume inspect ${COMPOSE_PROJECT_NAME}_orgs|grep /rpool/off/clones && docker volume rm ${COMPOSE_PROJECT_NAME}_orgs ) || true
	( docker volume inspect ${COMPOSE_PROJECT_NAME}_products|grep /rpool/off/clones && docker volume rm ${COMPOSE_PROJECT_NAME}_products ) || true
	( docker volume inspect ${COMPOSE_PROJECT_NAME}_product_images|grep /rpool/off/clones && docker volume rm ${COMPOSE_PROJECT_NAME}_product_images ) || true

save_orgs_to_mongodb:
	@echo "🥫 Saving exsiting orgs into MongoDB …"
	${DOCKER_COMPOSE_BUILD} run --rm backend perl -I/opt/product-opener/lib /opt/product-opener/scripts/migrations/2024_06_save_existing_orgs_to_mongodb.pl "/mnt/podata/orgs"

_bind_local:
ifeq ($(DOCKER_LOCAL_DATA),$(DOCKER_LOCAL_DATA_DEFAULT))
	@true
else ifeq ($(MOUNT_FOLDER),)
	$(error "Missing MOUNT_FOLDER variable")
else ifeq ($(MOUNT_VOLUME),)
	$(error "Missing MOUNT_VOLUME variable")
else
	@echo "🥫 Linking data volume ${COMPOSE_PROJECT_NAME}${PROJECT_SUFFIX}_${MOUNT_VOLUME} to directory ${DOCKER_LOCAL_DATA}/${MOUNT_FOLDER} …"
# local data
	mkdir -p "${DOCKER_LOCAL_DATA}/${MOUNT_FOLDER}"
	docker volume rm ${COMPOSE_PROJECT_NAME}${PROJECT_SUFFIX}_${MOUNT_VOLUME} || true
	docker volume create --label com.docker.compose.project=${COMPOSE_PROJECT_NAME}${PROJECT_SUFFIX} --label com.docker.compose.version=$(shell docker compose version --short) --label com.docker.compose.volume=${MOUNT_VOLUME} --driver=local -o type=none -o o=bind -o "device=${DOCKER_LOCAL_DATA}/${MOUNT_FOLDER}" ${COMPOSE_PROJECT_NAME}${PROJECT_SUFFIX}_${MOUNT_VOLUME}
endif

#------------#
# Production #
#------------#
create_external_volumes: _clean_old_external_volumes
	@echo "🥫 Creating external volumes (production only) …"
# zfs clones hosted on Ovh3 as NFS
	[[ -n "${PRODUCT_OPENER_FLAVOR_SHORT}" ]] || (echo "🥫 PRODUCT_OPENER_FLAVOR_SHORT is not set, can't create external volumes" && exit 1)
	docker volume create --driver=local --opt type=nfs --opt o=addr=${NFS_VOLUMES_ADDRESS},rw,nolock --opt device=:${NFS_VOLUMES_BASE_PATH}/users ${COMPOSE_PROJECT_NAME}_users
	docker volume create --driver=local --opt type=nfs --opt o=addr=${NFS_VOLUMES_ADDRESS},rw,nolock --opt device=:${NFS_VOLUMES_BASE_PATH}/${PRODUCT_OPENER_FLAVOR_SHORT}-products ${COMPOSE_PROJECT_NAME}_products
	docker volume create --driver=local --opt type=nfs --opt o=addr=${NFS_VOLUMES_ADDRESS},rw,nolock --opt device=:${NFS_VOLUMES_BASE_PATH}/${PRODUCT_OPENER_FLAVOR_SHORT}-images/products ${COMPOSE_PROJECT_NAME}_product_images
	docker volume create --driver=local --opt type=nfs --opt o=addr=${NFS_VOLUMES_ADDRESS},rw,nolock --opt device=:${NFS_VOLUMES_BASE_PATH}/orgs ${COMPOSE_PROJECT_NAME}_orgs
# local data
	docker volume create --driver=local -o type=none -o o=bind -o device=${DOCKER_LOCAL_DATA}/data ${COMPOSE_PROJECT_NAME}_html_data
	docker volume create --driver=local -o type=none -o o=bind -o device=${DOCKER_LOCAL_DATA}/build_cache ${COMPOSE_PROJECT_NAME}_build_cache
	docker volume create --driver=local -o type=none -o o=bind -o device=${DOCKER_LOCAL_DATA}/podata ${COMPOSE_PROJECT_NAME}_podata
# note for this one, it should be shared with pro instance in the future
	docker volume create --driver=local -o type=none -o o=bind -o device=${DOCKER_LOCAL_DATA}/export_files ${COMPOSE_PROJECT_NAME}_export_files

create_external_networks:
	@echo "🥫 Creating external networks (production only) …"
	docker network create --driver=bridge --subnet="172.30.0.0/16" ${COMPOSE_PROJECT_NAME}_webnet \
	|| echo "network already exists"

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
	( rm -rf build-cache/ || true )

clean_logs:
	( rm -f logs/* logs/apache2/* logs/nginx/* || true )


clean: goodbye hdown prune prune_cache clean_folders

# Run dependent projects
run_deps: clone_deps
	@for dep in ${DEPS} ; do \
		cd ${DEPS_DIR}/$$dep && $(MAKE) run; \
	done


# Clone dependent projects without running them (used to pull in yml for tests)
clone_deps:
	@mkdir -p ${DEPS_DIR}; \
	for dep in ${DEPS} ; do \
		echo $$dep; \
		if [ ! -d ${DEPS_DIR}/$$dep ]; then \
			echo "Cloning $$dep"; \
			git clone --filter=blob:none --sparse \
				https://github.com/openfoodfacts/$$dep.git ${DEPS_DIR}/$$dep; \
			echo "Cloned $$dep"; \
		else \
			cd ${DEPS_DIR}/$$dep && git pull; \
		fi; \
	done

#-----------#
# Utilities #
#-----------#

guard-%: # guard clause for targets that require an environment variable (usually used as an argument)
	@ if [ "${${*}}" = "" ]; then \
   		echo "Environment variable '$*' is not set"; \
   		exit 1; \
	fi;

