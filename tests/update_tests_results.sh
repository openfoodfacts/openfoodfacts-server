#!/bin/sh

# Update the expected results with the content of the actual results
# git diff can then be used to review the differences

# This script should be run only inside the po_backend_1 container

# Remove the categories stats file as it will not be present
# for tests run through GitHub actions
rm /mnt/podata/data/categories_stats/categories_nutriments_per_country.world.sto

# Unit tests

cd unit

perl attributes.t --results expected_test_results/attributes/
perl ecoscore.t --results expected_test_results/ecoscore/
perl forest_footprint.t --results expected_test_results/forest_footprint/
perl import_gs1.t --update-expected-results
perl ingredients.t --results expected_test_results/ingredients/
perl nutriscore.t --update-expected-results
perl packaging.t --results expected_test_results/packaging/
perl recipes.t --results expected_test_results/recipes/
perl import_convert_carrefour_france.t --update-expected-results

cd ..

# Integration tests

perl integration/import_csv_file.t --update-expected-results
perl integration/export.t --update-expected-results

