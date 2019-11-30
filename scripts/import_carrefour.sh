#!/bin/sh

./import_csv_file.pl --csv_file /home/off/scripts/carrefour.csv --user_id carrefour --comment "Import Carrefour" --source_id "carrefour" --source_name "Carrefour" --source_url "https://www.carrefour.fr" --images_dir /data/off/carrefour/images --manufacturer --skip_products_without_info
