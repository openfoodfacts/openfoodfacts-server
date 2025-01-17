# usage: source env/setenv.sh <environment>
# e.g. source env/setenv.sh obf
# e.g. source env/setenv.sh off-pro
# check that we were passed a environment parameter and that we have a corresponding .env file in the env/ directory

if [ -z "$1" ]; then
    echo "Usage: source env/setenv.sh <env>"
    echo "  where <env> is one of: off, obf, opf, opff, off-pro"
    return 1
fi

if [ ! -f env/env.$1 ]; then
    echo "Error: env/env.$1 does not exist"
    return 1
fi

set -o allexport

# Clear environment variables
COMPOSE_PROFILES=
COMPOSE_PROJECT_NAME=
MONGO_EXPOSE_PORT=
PRODUCT_OPENER_FLAVOR=
PRODUCT_OPENER_FLAVOR_SHORT=
PRODUCERS_PLATFORM=
MINION_QUEUE=

# Load environment variables from env file
source env/env.$1

# Set a variable that we use in Makefile to add an extra env file
# in addition to .env when we run docker compose
EXTRA_ENV_FILE=env/env.$1
LOAD_EXTRA_ENV_FILE=--env-file=env/env.$1

# eventually add lib for prod environment
if [[ -d /srv/$1/lib ]]
then
    PERL5LIB=/srv/$1/lib
fi

set +o allexport

# add (env) to the prompt
export PS1=${PS1:-}"($1) "
