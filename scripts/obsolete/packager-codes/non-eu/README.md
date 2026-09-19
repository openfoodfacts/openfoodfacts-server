# Non-EU Packager Codes

A Python application to download and manage non-EU packager codes, as listed on [the official page](https://webgate.ec.europa.eu/sanco/traces/output/non_eu_listsPerCountry_en.htm).

## Setup

Requires Python 3.5 or newer. To install, create a virtual environment using your favorite manager and activate it, for example:

```shell script
python3 -m venv ~/.pyenvs/packager-codes
source ~/.pyenvs/packager-codes/bin/activate
```

Install dependencies:

```shell script
pip install -r requirements.txt
```

## Usage

Simply run `python packager_codes.py --help` to see the main help.

To download or update packager code files in the directory `packager_codes_data`:

```shell script
python packager_codes.py sync
```

To display the status of the locally downloaded files as compared to the remote:

````shell script
python packager_codes.py status
````
