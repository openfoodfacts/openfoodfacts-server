#!/bin/bash
set -e

echo "🥫 Preparing Open Food Facts for IDX..."

# Fix path to initialization script
cd "$(dirname "$0")/../.." || exit 1
bash .devcontainer/idx/init.sh

# Clean up any existing containers
docker rm -f po_off-backend-1 po_off-frontend-1 po_off-minion-1 po_off-incron-1 po_off-postgres-1 po_off-dynamicfront-1 po_off-memcached-1 2>/dev/null || true

# Set environment variables
export COMPOSE_FILE="docker-compose.yml:docker/dev.yml:.devcontainer/idx/docker-compose.idx.yml"
export CONFIG2_PATH=$HOME/OFF_DATA/etc/Config2.pm
export SKIP_SYMLINKS=1

# Start the containers (using new docker compose syntax)
docker compose up -d

echo "🥫 Open Food Facts is now available at http://world.openfoodfacts.localhost:9000"