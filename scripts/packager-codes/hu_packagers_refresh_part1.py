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
update apikey file for geocode.maps.co (free account) in xx_packagers_refresh_part2.py 
from the government website,
download a pdf file of all establishments:
https://portal.nebih.gov.hu/-/elelmiszer-uzemlistak

download last version of https://github.com/tabulapdf/tabula-java/releases

convert the pdf file into csv (update release number and file name):
$ java -jar tabula-1.0.5-jar-with-dependencies.jar   enged_2024_05_22.pdf \
--lattice --format CSV --pages all > enged_2024_05_22.csv

# INSTALLATION
## install virtual environment
sudo apt install python3.11-venv
python3 -m venv venv
source venv/bin/activate

## install needed packages
pip install polars
pip install pyarrow # to convert to polars
pip install requests

# RUN
python3 xx_packagers_refresh_part1.py

This create a csv file XX-merge-UTF-8_no_coord.csv

# manual task
update XX-merge-UTF-8_no_coord.csv
because the first postal code is strikethrough text in the pdf
for the line "HU 302 ES;Hortobágyi Halgazdaság Zrt.;5127 4064 Nagyhegyes - Elep 02754"
replace "5127 4064 Nagyhegyes - Elep 02754"
by "4064 Nagyhegyes - Elep 02754"


python3 xx_packagers_refresh_part2.py 

Note that API sometimes return status code 500 or other, try to rerun before to debug it.
The file at_packagers_refresh_part2_index_tmp.txt is used during process, to resume processing only.

# POSTPROCESSING
- deactivate the virtual environment:
deactivate
- delete all temporary files
- update .sto file
'''

import polars as pl
import re


def handle_dates(text: str) -> str:
    # different variants
    # 2022.02.03
    # 2022.02
    # 2022-02-03
    # 202202.03
    split_text = re.split(
        r"\d{4}[\.|\-]*\s*\d{2}[\.|\-](?:\d{2})*", text, maxsplit=1)
    first_text = split_text[0]

    return first_text


def handle_county(address: str) -> str:
    split_s = re.split(r"/", address)
    # longer than /Vas
    # can be end of line with / and county is cropped while parsing
    if len(split_s) > 1 and (len(split_s[-1]) >= 3 or len(split_s[-1]) == 0):
        address = split_s[0]

    return address


def read_input_file(file_name: str) -> pl.dataframe.frame.DataFrame:

    df = pl.read_csv(file_name, separator=',', truncate_ragged_lines=True)

    # parsing issue:
    # address is found in next column (3),
    # leaving address column (2) null
    df = df.with_columns(
        pl.when(pl.col(df.columns[2]).is_null())
        .then(pl.col(df.columns[3]))
        .otherwise(pl.col(df.columns[2]))
        .alias(df.columns[2])
    )

    # take only first three columns (code, name, address)
    df = df[:, [0, 1, 2]]

    # rename columns name
    new_column_names = ['code', 'name', 'address']
    df = df.rename({i: j for i, j in zip(df.columns, new_column_names)})

    # ignore rows if first column is column name
    # or if missing code
    df = df.filter(df['code'].str.contains(code_prefix))
    df = df.with_columns(pl.col('code').str.replace_all('\r', ' '))
    df = df.with_columns(pl.col('code').str.replace_all('"', ' '))
    df = df.with_columns(pl.col('code').str.replace_all('-', ' '))
    df = df.with_columns(pl.col('code').str.replace_all('  ', ' '))
    df = df.with_columns(pl.col('code').str.strip_chars())
    df = df.with_columns((pl.col('code') + " ES").alias(df.columns[0]))

    # rm duplicates
    df = df.lazy().group_by('code').agg(pl.first('name'),
                                        pl.first('address')).sort('code').collect()

    # add lost record during conversion into csv
    # HU 13 TCS 003 ES;Magyar Agrár- és Élettudományi Egyetem Kaposvári Campus;7400 Kaposvár, Guba Sándor u. 40. / Somogy
    df = df.with_columns(pl.when(pl.col('code') == "HU 13 TCS 003 ES")
                         .then(pl.lit("Magyar Agrár- és Élettudományi Egyetem Kaposvári Campus"))
                         .otherwise(pl.col('name'))
                         .alias('name')
                         )

    # all others missing 'name' are strikethrough text
    df = df.filter(pl.col('name').is_not_null())

    df = df.with_columns(pl.col('name').str.replace_all('\r', ' '))
    df = df.with_columns(pl.col('name').str.replace_all('"', ' '))
    df = df.with_columns(pl.col('name').str.replace_all('”', ' '))

    # sometimes dates inside text
    # last update is text before first date occurence
    df = df.with_columns(pl.col('name').map_elements(
        lambda x: handle_dates(x), return_dtype=str))

    df = df.with_columns(pl.col('name').str.strip_chars())
    df = df.with_columns(pl.col('name').str.replace_all('  ', ' '))

    df = df.with_columns(pl.col('address').str.replace_all('\r', ' '))
    df = df.with_columns(pl.col('address').str.strip_chars())
    df = df.with_columns(pl.col('address').str.replace_all('  ', ' '))

    # all missing 'address' are strikethrough text
    df = df.filter(pl.col('address').is_not_null())
    # parsing issue
    # sometimes when 'address' is strikethrough text
    # 'address' value is value from next column
    # 'address' value is then less than 7 characters
    # examples: EPC, SH, E  P C
    df = df.filter(pl.col('address').str.len_chars() > 6)

    # remove "/ <county>" at the end of the address
    # but not 10/A.
    # smallest county is "Vas"
    df = df.with_columns(pl.col('address').map_elements(
        lambda x: handle_county(x), return_dtype=str))
    # remove "(text)" in middle of address
    # as well as "(begining of text" at end of the line
    df = df.with_columns(
        pl.col('address').str.replace(r"\(.*?\)|\(.*", "")
        .alias('address')
    )
    # remove hrsz (= helyrajzi szám), lot number
    # 7747 Belvárdgyula, Hrsz 1052 (comma, no dot)
    # 7054 Tengelic, Rákóczi u. 43. hrsz 262 (no comma, no dot)
    # 2310 Szigetszentmiklós, Rákóczi u. 78. hrsz. 1395 (no command, dot)
    # 4030 Debrecen, Borzán Gáspár u. 10., hrsz. 11273 (comma, dot)
    df = df.with_columns(
        pl.col("address").str.replace(r",?\s*[H|h]rsz\.?.*", "")
        .alias('address')
    )
    # keep 2 first parts of teach line
    # postal code city, street, additional information
    df = df.with_columns(
        address=pl.col('address').str.split(
            ",").list.slice(0, 2).list.join(",")
    )

    return df


if __name__ == "__main__":
    input_file = 'enged_2024_05_22.csv'
    code_prefix = 'HU'
    output_file = f'{code_prefix}-merge-UTF-8_no_coord.csv'

    df = read_input_file(input_file)

    df.write_csv(output_file, separator=';')
