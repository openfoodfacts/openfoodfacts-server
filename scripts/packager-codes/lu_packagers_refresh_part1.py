'''
This file is part of Product Opener.
Product Opener
Copyright (C) 2011-2024 Association Open Food Facts
Contact: contact@openfoodfacts.org
Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
Product Opener is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.
You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

# PREREQUISITES
python3
verify the urls and variables in main

# INSTALLATION
## install virtual environment
sudo apt install python3.11-venv
python3 -m venv venv
source venv/bin/activate

## install needed packages
pip install polars
pip install pyarrow # for polars
pip install requests
pip install beautifulsoup4

# RUN
python3 xx_packagers_refresh_part1.py

This create a csv file XX-merge-UTF-8_no_coord.csv

python3 xx_packagers_refresh_part2.py 

The file at_packagers_refresh_part2_index_tmp.txt is used during process, to resume processing only.

# POSTPROCESSING
- deactivate the virtual environment:
deactivate
- delete all temporary files
- update .sto file
'''

import polars as pl
from bs4 import BeautifulSoup
import requests
import sys


def extract_row_from_online_table(row: list) -> dict:
    '''
    columns 2, 3 and 4 define the address
    remove hyphen from the code
    '''
    row_data = {}
    # start by code_prefix (and end by code_suffix)
    if not row[0].strip().startswith(f'{code_prefix} '):
        approval_number = f"{code_prefix} {
            row[0].replace('-', '').strip()} {code_suffix}"
    else:
        approval_number = row[0].strip()
    address = row[2].replace('<br/>', ', ').strip() + \
        ", " + row[3] + ", " + row[4]
    address = address.replace(' ', '')
    address = address.replace(',,', ',')
    address = address.replace(', ,', ',')
    if address.startswith(','):
        address = address[1:].strip()

    row_data['code'] = approval_number
    row_data['name'] = row[1]
    row_data['address'] = address

    return row_data


def contains_number_check(value: str) -> bool:
    contains_number = False
    for ch in value:
        if ch.isdigit():
            contains_number = True
            break

    return contains_number


def parse_from_website(url: str) -> pl.dataframe.frame.DataFrame:
    try:
        html_content = requests.get(url, headers=headers).text
    except requests.exceptions.ConnectionError:
        print(f"parse_from_website, cannot get url {url}")

    if not html_content:
        print(f"parse_from_website, error with request {url}")
        sys.exit(1)

    soup = BeautifulSoup(html_content, 'html.parser')

    tables = soup.find_all('table')

    data_rows = []
    for table in tables:
        for tr in table.find_all('tr'):
            raw_row_data = [td.get_text(separator=", ")
                            for td in tr.find_all('td')]
            print(f"parse_from_website, raw_row_data: {raw_row_data}")

            contains_number = contains_number_check(raw_row_data[0])

            # ignore []
            # ignore ['Ovine'] or ['Cutting', 'Bovine'] (due to merged cells)
            # keep only first 4 columns
            # ignore if first column is not a number
            if len(raw_row_data) > 2 and contains_number:
                print("parse_from_website, valid condition")
                extracted_row = extract_row_from_online_table(raw_row_data)
                data_rows.append(extracted_row)

    if not data_rows:
        print(f"parse_from_website, parsing issue for {url}")
        sys.exit(1)

    df = pl.DataFrame(data_rows)
    return df


def get_data_online():
    # Etablissements agréés
    df = parse_from_website(url_etablissements_agrees)

    df.write_csv(output_file, separator=';')


if __name__ == "__main__":
    code_prefix = 'LU'
    code_suffix = 'CE'
    output_file = f'{code_prefix}-merge-UTF-8_no_coord.csv'
    # use user agent for requests
    headers = {'User-Agent': 'packager-openfoodfacts'}

    # urls for files
    # Etablissements agréés
    url_etablissements_agrees = "https://securite-alimentaire.public.lu/fr/professionnel/Denrees-alimentaires/Etablissements-agrees.html"

    get_data_online()
