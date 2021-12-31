# source it before launching platform
# NOTE: this is an addition to .env file, not a standalone file !
export COMPOSE_PROJECT_NAME=po_pro
# we do not want postgres on the pro side, we use the one from off
export COMPOSE_PROFILES=
# Expose mongo on a different port to avoid conflict with public platform
export MONGO_EXPOSE_PORT=27018
# Tweak config for producer platform
export PRODUCERS_PLATFORM=1
export MINION_QUEUE=pro.openfoodfacts.localhost
# use a different port for minion admin
# Note: we do not change PRODUCT_OPENER_DOMAIN for Config2.pm will handle this
# neither do we change PRODUCT_OPENER_FLAVOR, as off-pro use same contents as off

set_ps1 () {
    export PS1=${PS1:-}"(pro) "
}
set_ps1;
