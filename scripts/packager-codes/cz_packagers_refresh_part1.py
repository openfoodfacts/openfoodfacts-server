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
    download a csv of all establishments:
    https://en.svscr.cz/registered-subjects/lists-of-establishments/

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
python3 xx_packagers_refresh_part1.py

This create a csv file XX-merge-UTF-8_no_coord.csv

python3 xx_packagers_refresh_part2.py 

Note that API sometimes return status code 500 or other, try to rerun before to debug it.
The file at_packagers_refresh_part2_index_tmp.txt is used during process, to resume processing only.

# POSTPROCESSING
- deactivate the virtual environment:
deactivate
- delete all temporary files
- update .sto file
'''

import os
import polars as pl


def read_input_file() -> pl.dataframe.frame.DataFrame:
    current_directory = '.'

    dfs = []
    for filename in os.listdir(current_directory):
        if filename.endswith('.csv') and filename != output_file:
            print(filename)

            file_path = os.path.join(current_directory, filename)

            try:
                df = pl.read_csv(filename)

                df = df.select(df.columns[0:3])

                new_column_names = ['code', 'name', 'address']
                df = df.rename(
                    {i: j for i, j in zip(df.columns, new_column_names)})

                # append suffix EK at the end of the packaging codes
                df = df.with_columns(
                    (pl.col(df.columns[0]) + " ES").alias(df.columns[0]))

                dfs.append(df)

            except Exception as e:
                print(f"Error processing {file_path}: {e}")
                sys.exit(1)

    # Concatenate all DataFrames into a single DataFrame
    result_df = pl.concat(dfs)

    return result_df


if __name__ == "__main__":
    output_file = 'CZ-merge-UTF-8_no_coord.csv'

    df = read_input_file()

    # rm duplicates
    df = df.lazy().group_by('code').agg(pl.first('name'),
                                        pl.first('address')).sort('code').collect()

    df.write_csv(output_file, separator=';')
