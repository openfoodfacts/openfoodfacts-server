#!/bin/bash
# Add idx-specific configuration
echo "COMPOSE_FILE=docker-compose.yml;docker/dev.yml;.idx/docker-compose.idx.yml" >> .env
echo "PRODUCT_OPENER_PORT=9000" >> .env
echo "PRODUCT_OPENER_EXPOSE=0.0.0.0:" >> .env

# Skip reset_owner and run dev
make create_folders
make build_taxonomies
make build_lang
make _up
make import_sample_data
make create_mongodb_indexes
make refresh_product_tags

echo "🥫 Open Food Facts is now available at port 9000!"