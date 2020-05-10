
# Requirements
- node (https://nodejs.org/)
- miller >=5.0 (https://johnkerl.org/miller/doc/)

# Usage
Install the xml2csv node module found here: https://github.com/odtvince/xml2csv

Put all the xml files to import into the `equadis-data` directory

Then execute:
```
node equadis-xml2csv.js
./equadis2off.sh > equadis-data.tsv
./dereference.sh equadis-data.tsv
```

