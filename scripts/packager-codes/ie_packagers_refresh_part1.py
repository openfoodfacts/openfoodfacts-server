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
pip install xlsx2csv
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
    row_data = {}
    # start by code_prefix (and end by code_suffix)
    if not row[0].strip().startswith(f'{code_prefix} '):
        approval_number = f"{code_prefix} {row[0].strip()} {code_suffix}"
    else:
        approval_number = row[0].strip()
    address = row[2].replace('<br/>', ', ').strip() + ", " + row[3]
    address = address.replace(' ', '')
    address = address.replace(',,', ',')
    address = address.replace(', ,', ',')
    if address.startswith(','):
        address = address[1:].strip()

    row_data['code'] = approval_number
    row_data['name'] = row[1]
    row_data['address'] = address

    return row_data


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
            # ignore []
            # ignore ['Ovine'] or ['Cutting', 'Bovine'] (due to merged cells)
            # keep only first 4 columns
            if len(raw_row_data) > 2:
                extracted_row = extract_row_from_online_table(raw_row_data)
                data_rows.append(extracted_row)

    if not data_rows:
        print(f"parse_from_website, parsing issue for {url}")
        sys.exit(1)

    df = pl.DataFrame(data_rows)
    return df


def download_file(url: str, file_name: str) -> None:
    response = requests.get(url)
    if response.status_code == 200:
        with open(file_name, 'wb') as f:
            f.write(response.content)
    else:
        print(f'download_file, failed to download file {file_name}')
        sys.exit(1)


def create_df_dafm_meat() -> pl.dataframe.frame.DataFrame:
    file_name_dafm_meat = "dafm_meat.xlsx"
    download_file(url_dafm_meat, file_name_dafm_meat)
    df = pl.read_excel(file_name_dafm_meat)
    df = df[:, [0, 1, 2]]

    # rename columns name to avoid error because of unnamed third column
    new_column_names = ['code', 'name', 'address']
    df = df.rename({i: j for i, j in zip(df.columns, new_column_names)})

    # 2 occurences of integer ending by space for code
    df = df.with_columns(pl.col(df.columns[0]).str.replace_all(" ", ""))
    # replace non-integer by null for code
    df = df.with_columns(pl.col(df.columns[0]).str.to_integer(strict=False))
    # keep only where integer in code column
    df = df.drop_nulls(subset=[df.columns[0]])
    # add prefix and suffix
    df = df.with_columns((f"{code_prefix} " + pl.col(df.columns[0]).cast(
        pl.String) + f" {code_suffix}").alias(df.columns[0]))

    return df


def create_df_dafm_milk() -> pl.dataframe.frame.DataFrame:
    file_name_dafm_milk = "dafm_milk.xlsx"
    download_file(url_dafm_milk, file_name_dafm_milk)
    df = pl.read_excel(file_name_dafm_milk)

    # rename columns name to avoid error because of unnamed third column
    new_column_names = ['code', 'name', 'skip', 'address']
    df = df.rename({i: j for i, j in zip(df.columns, new_column_names)})

    # remove unnecessary spaces and new lines
    df = df.with_columns(
        pl.col(df.columns[1]).str.replace_all(r"\s+", " ").str.strip_chars(),
        pl.col(df.columns[2]).str.replace_all(r"\s+", " ").str.strip_chars()
    )
    # combine columns 1 and 2
    # replace "as across" by legal name (there is " as across " one time)
    # first, relpace null by as across
    df = df.with_columns(pl.col(df.columns[2]).fill_null("as across"))
    df = df.with_columns(
        pl.when(pl.col(df.columns[2]).cast(pl.String) == "as across")
        .then(
            pl.concat_str([
                pl.col(df.columns[1])
            ])
        )
        .otherwise(
            pl.concat_str([
                pl.lit("Legal name: "),
                pl.col(df.columns[1]),
                pl.lit("\nTrading name: "),
                pl.col(df.columns[2]).cast(pl.String)
            ])
        )
        .alias(df.columns[1])
    )

    df = df[:, [0, 1, 3]]

    # legal name: 1, trading name: 2
    # 2 occurences of integer ending by space for code
    # IE2151EC (Ireland) starta by 2 spaces
    df = df.with_columns(pl.col(df.columns[0]).str.replace_all(
        '"', '').str.replace_all('\n\n', ''))

    # replace non-integer by null for code
    # integer starting by 1 or starting by IE (Ireland)
    # keep all rows starting by IE
    df_a = df.filter((pl.col(df.columns[0]).str.starts_with(code_prefix)))
    # add spaces
    df_a = df_a.with_columns(
        pl.when(~pl.col(df.columns[0]).str.contains(' '))
        .then(pl.col(df.columns[0]).str.replace_all(code_prefix, f'{code_prefix} ').str.replace_all(code_suffix, f' {code_suffix}'))
        .otherwise(pl.col(df.columns[0]))
        .alias(df.columns[0])
    )

    # keep all row being integer
    df_b = df.with_columns(pl.col(df.columns[0]).str.to_integer(
        strict=False).cast(pl.String))
    # keep only where integer in code column
    df_b = df_b.drop_nulls(subset=[df_b.columns[0]])
    # add prefix and suffix
    df_b = df_b.with_columns((f"{code_prefix} " + pl.col(df.columns[0]).cast(
        pl.String) + f" {code_suffix}").alias(df.columns[0]))
    # missing comma in "3 Main St. Ballybunion, Co. Kerry" (Ireland)
    df_b = df_b.with_columns(pl.col(df.columns[2]).str.replace(
        "3 Main St. Ballybunion", "3 Main St., Ballybunion"))

    df = pl.concat([df_a, df_b])

    df = df.with_columns(
        pl.col(df.columns[2])
        .str.strip_chars()
        .str.replace_all(r"\n", ", ")
        .str.replace_all(r"\s+", " ")
        .str.replace_all(r",,", ",")
        .str.replace_all(r", ,", ",")
    )

    return df


def get_data_online():
    # Local Authority (LA)
    df_la_establishment = parse_from_website(url_la_establishment)

    # Department of Agriculture, Food and the Marine (DAFM)
    df_dafm_meat = create_df_dafm_meat()
    df_dafm_milk = create_df_dafm_milk()

    # Health Service Executive (HSE)
    # no codes in url_hse_butcher
    # df_hse_butcher = parse_from_website(url_hse_butcher)
    df_hse_establishments = parse_from_website(url_hse_establishments)

    # Sea-Fisheries Protection Authority (SFPA)
    df_sfpa_establishments = parse_from_website(url_sfpa_establishments)
    df_sfpa_freezer = parse_from_website(url_sfpa_freezer)
    df_sfpa_factory = parse_from_website(url_sfpa_factory)

    df = pl.concat([
        df_la_establishment,
        df_dafm_meat,
        df_dafm_milk,
        df_hse_establishments,
        df_sfpa_establishments,
        df_sfpa_freezer,
        df_sfpa_factory
    ])
    df.write_csv(output_file, separator=';')


if __name__ == "__main__":
    code_prefix = 'IE'
    code_suffix = 'EC'
    output_file = f'{code_prefix}-merge-UTF-8_no_coord.csv'
    # use user agent for requests
    headers = {'User-Agent': 'packager-openfoodfacts'}

    # urls for files
    # Local Authority (LA)
    url_la_establishment = "https://oapi.fsai.ie/LAApprovedEstablishments.aspx"
    # Department of Agriculture, Food and the Marine (DAFM)
    url_dafm_meat = "https://assets.gov.ie/111269/1330a536-cceb-4e30-889a-f961bd8e6afc.xlsx"
    url_dafm_milk = "https://assets.gov.ie/96939/a164c862-d696-4a6e-9ffc-ff9c3aa2ac40.xlsx"
    # Health Service Executive (HSE)
    # no codes
    # url_hse_butcher = "https://oapi.fsai.ie/AuthReg99901Establishments.aspx"
    url_hse_establishments = "https://oapi.fsai.ie/HSEApprovedEstablishments.aspx"
    # Sea-Fisheries Protection Authority (SFPA)
    url_sfpa_establishments = "https://www.sfpa.ie/What-We-Do/Seafood-Safety/Registration-Approval-of-Businesses/List-of-Approved-Establishments/Approved-Establishments"
    url_sfpa_freezer = "https://www.sfpa.ie/What-We-Do/Seafood-Safety/Registration-Approval-of-Businesses/List-of-Approved-Establishments/Approved-Freezer-Vessels"
    url_sfpa_factory = "https://www.sfpa.ie/What-We-Do/Seafood-Safety/Registration-Approval-of-Businesses/List-of-Approved-Establishments/Approved-Factory-Vessels"

    get_data_online()
