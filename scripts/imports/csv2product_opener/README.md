## What

Import products from standardized CSV to Open X Facts. By standard we mean that the CSV file should contain fields that are existing in Product Opener:
* at least the `code` field, containing an EAN barcode
* at minimum one other field: the `product_name`, the `categories`, the `labels` fields are good candidates

The order of the fields is not important.


## Recommendations

If you are importing more than 20-50 products, you should create a dedicated Open Food Facts account, ending with `-import`.

## Credentials

Credentials are read from config.ini file, following [INI file format](https://en.wikipedia.org/wiki/INI_file). This one should be like this:

```
[auth]
username = offusername
password = the_corresponding_password
```

## Usage

From the --help option:

```
csv2product_opener.py [-h] [--limit LIMIT] [--environment {net,org}] [--country COUNTRY]
                           [--flavor {off,opf,obf,opff}] [--import]
                           [csv_file]
```

By default, imports are made on staging platform (openfoodfacts **.net**). 

Script can be tested with:

```
echo -e "code,product_name\n123456990123,Test Product" | \
    python3 csv2product_opener.py --import
```

or

```
cat source.csv | python3 csv2product_opener.py --limit 1 --import
```

or

```
python3 csv2product_opener.py source.csv --limit 1 --import
```

## Reference

```
positional arguments:
  csv_file              Path to the CSV file (defaults to stdin if not provided)

options:
  -h, --help            show this help message and exit
  --limit LIMIT         Limit the number of products to process
  --environment {net,org}
                        Open Food Facts environment to use: "net" (default) or "org". "net" does
                        not work with "opf", "obf", or "opff" flavors.
  --country COUNTRY     Country code to use for Open X Facts (default: "world"). All countries
                        have a default language except "world" which defaults to English. For
                        example, "fr", for France, defaults to French.
  --flavor {off,opf,obf,opff}
                        Open Food Facts API flavor to use: "off", "opf" (default), "obf", or
                        "opff"
  --import              Actually import products to OpenFoodFacts
```


## Installation

The script should work if you install openfoodfacts python library by hand.

If you want to play reproducible installation, first install [uv](https://docs.astral.sh/uv/) and:

```
cd /dir/of/the/script
uv init
uv add openfoodfacts
uv run csv2product_opener.py
```
