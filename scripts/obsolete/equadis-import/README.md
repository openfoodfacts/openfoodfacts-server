
# Requirements
- node (https://nodejs.org/)
- miller >=5.0 (https://johnkerl.org/miller/doc/)

On stretch:
apt-get -t stretch-backports install miller

# Usage
Install the xml2csv node module found here: https://github.com/odtvince/xml2csv

As the off user:

```
mkdir ~/npm-global
export NPM_CONFIG_PREFIX=~/.npm-global
/srv/off-pro/scripts/equadis-import# git clone https://github.com/odtvince/xml2csv.git
/srv/off-pro/scripts/equadis-import# cd xml2csv/
/srv/off-pro/scripts/equadis-import/xml2csv# npm link
/srv/off-pro/scripts/equadis-import/xml2csv# cd ..
/srv/off-pro/scripts/equadis-import# npm link xml2csv
```

Put all the xml files to import into the `equadis-data` directory

Then execute:
```
node equadis-xml2csv.js
./equadis2off.sh > equadis-data.tsv
./dereference.sh equadis-data.tsv
```

