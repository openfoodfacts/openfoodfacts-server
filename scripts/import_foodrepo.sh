#!/bin/sh

./import_csv_file.pl --csv_file /home/off/scripts/foodrepo.csv --user_id foodrepo --comment "Import foodrepo.org" --source_id "openfood-ch" --source_name "FoodRepo" --source_url "https://www.foodrepo.org" --source_licence "Creative Commons Attribution 4.0 International License" --source_licence_url "https://creativecommons.org/licenses/by/4.0/" --skip_products_without_info --skip_existing_values --define countries="Switzerland"
