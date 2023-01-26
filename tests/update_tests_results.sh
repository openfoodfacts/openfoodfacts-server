#!/bin/sh

# Update the expected results with the content of the actual results
# git diff can then be used to review the differences

# This script should be run only inside the po_backend_1 container
# or the test version of it

if ! [ -d unit ];
then
    cd /opt/product-opener/test
fi

# Remove the categories stats file as it will not be present
# for tests run through GitHub actions
rm /mnt/podata/data/categories_stats/categories_nutriments_per_country.world.sto

# Unit tests

cd unit

perl attributes.t --update-expected-results
perl ecoscore.t --update-expected-results
perl forest_footprint.t --update-expected-results
perl import_gs1.t --update-expected-results
perl ingredients.t --update-expected-results
perl nutriscore.t --update-expected-results
perl packaging.t --update-expected-results
perl recipes.t --update-expected-results
perl import_convert_carrefour_france.t --update-expected-results

cd ..

# Integration tests

for FILE in integration/*.t; do perl $FILE --update-expected-results; done

