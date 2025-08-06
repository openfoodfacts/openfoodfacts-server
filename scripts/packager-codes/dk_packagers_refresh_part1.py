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
    download a Excel file of all establishments:
    https://foedevarestyrelsen.dk/kost-og-foedevarer/start-og-drift-af-foedevarevirksomhed/autorisation-og-registrering/registrerede-og-autorisede-foedevarevirksomheder

# INSTALLATION
## install virtual environment
sudo apt install python3.11-venv
python3 -m venv venv
source venv/bin/activate

## install needed packages
pip install pandas
pip install openpyxl
pip install xlsx2csv
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

import pandas as pd


def read_input_file(file_name: str) -> pd.core.frame.DataFrame:

    # could not use polars to read excel, used pandas instead
    # ignore two first tabs
    ids = [i for i in range(2, 21)]
    # skip first few rows (~page header)
    excel_file = pd.read_excel(
        'Autoriserede_Foedevarevirksomheder_Excel(1).xlsx', sheet_name=ids, skiprows=5)
    # take only first three columns (code, name, address)
    filtered_dfs = [df.iloc[:, :3] for df in excel_file.values()]
    # combine all tabs into single one
    df = pd.concat(filtered_dfs)

    # rename columns name
    df.columns = ['code', 'name', 'address']

    # one approval number can have more than a single category
    # this leads to null rows in the df
    df.dropna(how='all', inplace=True)

    # some rows are missing approval number
    df.dropna(subset=['code'], inplace=True)

    # some approval number became float (60.0)
    df['code'] = df['code'].apply(lambda x: str(x).replace('.0', ''))

    # append prefix DF and suffix EK
    # at the end of the packaging codes
    df['code'] = df['code'].str.strip()
    df['code'] = df['code'].apply(lambda x: f"DK {x} EF")

    # rm duplicates
    df.drop_duplicates(subset="code", keep="first", inplace=True)

    return df


if __name__ == "__main__":
    input_file = 'Autoriserede_Foedevarevirksomheder_Excel(1).xlsx'
    output_file = 'DK-merge-UTF-8_no_coord.csv'

    df = read_input_file(input_file)

    df.to_csv(output_file, sep=';', index=False)
