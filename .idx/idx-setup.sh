#!/bin/bash

# Create necessary directories
mkdir -p ~/OFF_DATA/{html_data,build-cache/taxonomies-result,ingredients}
mkdir -p ~/OFF_DATA/off/{products,html}
mkdir -p ~/OFF_DATA/obf/{products,html}
mkdir -p ~/OFF_DATA/opf/{products,html}
mkdir -p ~/OFF_DATA/opff/{products,html}

# Create symbolic links for data files
touch ~/OFF_DATA/html_data/data-fields.md
touch ~/OFF_DATA/html_data/data-fields.txt

# Run the development environment with our custom environment variables
COMPOSE_FILE="docker-compose.yml;docker/dev.yml" docker compose --env-file=.env.idx --env-file=.env up -d

echo "IDX environment is now running. Access the app at http://localhost:8000"