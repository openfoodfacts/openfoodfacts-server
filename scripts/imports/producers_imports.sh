#!/usr/bin/env bash

# Equadis import
./scripts/imports/equadis/run_equadis_import.sh
# Agena import
./scripts/imports/agena3000/run_agena3000_import.sh
# Carrefour
./scripts/imports/carrefour/import_carrefour.sh

# Export
./scripts/export_producers_platform_data_to_public_database.sh