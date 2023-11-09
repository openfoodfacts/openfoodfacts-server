# NOTE: this is an addition to .env file, not a standalone file !
COMPOSE_PROJECT_NAME=po_pro
# we do not want postgres on the pro side, we use the one from off
COMPOSE_PROFILES=
# Expose mongo on a different port to avoid conflict with public platform
MONGO_EXPOSE_PORT=27018
# Tweak config for producer platform
PRODUCERS_PLATFORM=1
MINION_QUEUE=pro.openfoodfacts.localhost
# use a different port for minion admin
# Note: we do not change PRODUCT_OPENER_DOMAIN for Config2.pm will handle this
# neither do we change PRODUCT_OPENER_FLAVOR, as off-pro use same contents as off

# Set a variable that we use in Makefile to add an extra env file 
# in addition to .env when we run docker-compose
EXTRA_ENV_FILE=env.pro
LOAD_EXTRA_ENV_FILE=--env-file=env.pro
