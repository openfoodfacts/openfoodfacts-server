#!/bin/sh

# Update the expected results with the content of the actual results
# git diff can then be used to review the differences

perl attributes.t --results expected_test_results/attributes/
perl ecoscore.t --results expected_test_results/ecoscore/
perl forest_footprint.t --results expected_test_results/forest_footprint/
perl import_gs1.t --results expected_test_results/import_gs1/
perl ingredients.t --results expected_test_results/ingredients/
perl nutriscore.t --results expected_test_results/nutriscore/
perl packaging.t --results expected_test_results/packaging/
perl recipes.t --results expected_test_results/recipes/
perl export.t --update-expected-results
perl import_convert_carrefour_france.t --update-expected-results

