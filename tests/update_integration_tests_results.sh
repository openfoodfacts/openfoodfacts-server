#!/bin/sh

# Update the integration tests expected results with the content of the actual results
# git diff can then be used to review the differences

# This script should be run only inside the po_backend_1 container
# or the test version of it

if ! [ -d unit ];
then
    cd /opt/product-opener/test
fi

# Remove the categories stats file as it will not be present
# for tests run through GitHub actions
rm /mnt/podata/data/categories_stats/
rm /mnt/podata/data/categories_stats/*.*

# Integration tests

for FILE in integration/*.t; do perl $FILE --update-expected-results; done

