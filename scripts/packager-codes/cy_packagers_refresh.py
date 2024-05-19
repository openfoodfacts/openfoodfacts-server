'''
This file is part of Product Opener.
Product Opener
Copyright (C) 2011-2023 Association Open Food Facts
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


# REMARK
Even using Google map, addresses are rarely found on the map, 
hence, we will create csv file having name and addresses only,
without coordinates

# PREREQUISITES
python3
from the government website,
https://www.moa.gov.cy/moa/vs/vs.nsf/vs13_en/vs13_en?OpenDocument
download all file

download last version of https://github.com/tabulapdf/tabula-java/releases

In the folder containing all pdf files, run:
$ find . -maxdepth 1 -type f -name '*.pdf' -print0 | xargs -0 -I {} bash -c \
'java -jar tabula-1.0.5-jar-with-dependencies.jar "{}" --lattice --format CSV \
--pages all > "$(basename "{}" .pdf)_tabula.csv"

# INSTALLATION
## install virtual environment
sudo apt install python3.11-venv
python3 -m venv venv
source venv/bin/activate

## install needed packages
pip install pyarrow # to convert to polars
pip install polars
pip install requests

# RUN
python3 xx_packagers_refresh.py

This create XX-merge-UTF-8.csv (all files merged into a single one)

# POSTPROCESSING
- deactivate the virtual environment:
deactivate
- delete all temporary files
- update .sto file
'''


import os
import polars as pl
import sys


def split_name_address(input_name_address: str, output: str) -> str:
    name = ""
    address = ""
    lines = input_name_address.split('\n')
    lines = [x.strip() for x in lines]
    name += lines[0]
    for line in lines[1:]:
        line_split = line.split(',')
        
        if line_split[0][:4].isdigit():
            address += ', ' + line_split[0]
        else:
            address += line_split[0]

        name += ", ".join(line_split[1:])

    if output == 'name':
        return name
    else:
        return address


def read_all_csv() -> pl.dataframe.frame.DataFrame:
    pdf_directory = '.'

    dfs = []

    for filename in os.listdir(pdf_directory):
        if filename.endswith('.csv') and filename != output_file:
            print(filename)

            pdf_path = os.path.join(pdf_directory, filename)

            try:
                df = pl.read_csv(filename, truncate_ragged_lines=True)

                # remove empty columns (null, "")
                columns_to_drop = []
                for i in range(len(df.columns)):
                    if df[df.columns[i]].null_count() == df[df.columns[i]].len():
                        columns_to_drop.append(df.columns[i])

                    # invalid series dtype: expected `String`, got `i64`
                    if df[df.columns[i]].dtype == pl.String:
                        if (df[df.columns[i]].str.len_chars() == 0).all():
                            columns_to_drop.append(df.columns[i])
                
                df = df.drop(columns_to_drop)


                # remove header inside column
                df = df.filter(pl.col(df.columns[1]) != df.columns[1])

                # transform 0022 to CY 0022 (EK)
                df = df.with_columns(pl.col(df.columns[1]).map_elements(lambda x: "CY " + x if not x.startswith('CY') else x, return_dtype=str))
                # make sure there is a space after CY
                df = df.with_columns(pl.col(df.columns[1]).map_elements(lambda x: x.replace('CY', 'CY ') if not x.startswith('CY ') else x, return_dtype=str))                

                # case CY and code are split in 2 columns
                # set conditions to find these cases
                name_prefix = df[df.columns[1]].str.starts_with("CY").all()
                # 3 because we just added a space at the end before
                name_length = (df[df.columns[1]].str.len_chars() == 3).all()
                # apply changes if conditions are met
                if name_prefix and name_length:
                    df = df.with_columns((pl.col(df.columns[1]) + " " + pl.col(df.columns[2])).alias(df.columns[1]))
                    df = df.drop(df.columns[2])

                # remove new line characters
                df = df.with_columns(pl.col(df.columns[1]).str.replace_all('\n', ' '))
                df = df.with_columns(pl.col(df.columns[1]).str.replace_all('\r', ' '))
                df = df.with_columns(pl.col(df.columns[1]).str.replace_all('  ', ' '))
                df = df.with_columns(pl.col(df.columns[2]).str.replace_all('\n', ' '))
                df = df.with_columns(pl.col(df.columns[2]).str.replace_all('\r', ' '))
                df = df.with_columns(pl.col(df.columns[2]).str.replace_all('  ', ' '))
                df = df.with_columns(pl.col(df.columns[3]).str.replace_all('\n', ' '))
                df = df.with_columns(pl.col(df.columns[3]).str.replace_all('\r', ' '))
                df = df.with_columns(pl.col(df.columns[3]).str.replace_all('  ', ' '))

                df = df.select(df.columns[1:4])
                new_column_names = ['code', 'name', 'address']
                df = df.rename({i: j for i, j in zip(df.columns, new_column_names)})

                # "9. fish and fishery products 9.1.2024Dataportal_tabula.csv" has a name that is empty
                df = df.filter(pl.col('name').is_not_null())    

                # append suffix EK at the end of the packaging codes
                df = df.with_columns((pl.col(df.columns[0]) + " EK").alias(df.columns[0]))

                dfs.append(df)

            except Exception as e:
                print(f"Error processing {pdf_path}: {e}")
                sys.exit(1)

    # Concatenate all DataFrames into a single DataFrame
    result_df = pl.concat(dfs)

    return result_df



output_file = 'CY-merge-UTF-8.csv'

df = read_all_csv()

# rm duplicates
df = df.lazy().group_by('code').agg(pl.first('name'), pl.first('address')).sort('code').collect()

df.write_csv(output_file, separator=';')
