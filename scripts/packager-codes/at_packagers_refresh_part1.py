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
update apikey file for geocode.maps.co (free account) in at_packagers_refresh_part2.py 
from the Austrian government website,
    download all pdf below "Zugelassene Betriebe für Lebensmittel gemäß VO(EG) Nr. 853/2004 / 
    Lists of approved food establishments according to Reg.(EC) No 853/2004" in the following page:
    https://vis.statistik.at/vis/veroeffentlichungen/zugelassene-betriebe

# INSTALLATION
## install virtual environment
sudo apt install python3.11-venv
python3 -m venv venv
source venv/bin/activate

## install needed packages
pip install "camelot-py[base]"
pip install --upgrade PyPDF2==2.12.1
pip install opencv-python
pip install pyarrow # to convert to polars
pip install polars
pip install requests

# RUN
python3 at_packagers_refresh_part1.py

This create all csv files (useful for debugging) and AT-merge-UTF-8_no_coord.csv (all files merged into a single one)

Manual task: page 98 from I21.pdf is truncated after Hafnerstraße 2 / 2, you have to complete this row + add all rows after in the AT-merge-UTF-8_no_coord.csv file
    AT 31592 EG;Mayer Margarete;Hafnerstraße 2 / 2, 4441 Behamberg
    AT 31594 EG;Kammlander Jürgen und Mitges. Landwirtschaft;Hauptstraße 57, 2405 Hundsheim
    AT 31595 EG;PAN natur - Gesundheit für Boden, Pflanze, Tier und Mensch;Harmannstein 37, 3922 Großschönau
    AT 31596 EG;Weber Otmar jun;Ortsstraße 61, 2292 Engelhartstetten
    AT 31599 EG;Göttinger Manfred;Untere Hauptstraße 17, 2111 Tresdorf
    AT 31600 EG;STOCKERT, LUKACS, SPRINGER, STREISSLER, PERSONENGEMEINSCHAFT;Markt 25 Fleischhauerei, 3193 St.Aegyd/Neuwalde

python3 at_packagers_refresh_part2.py 

Note that API sometimes return status code 500 or other, try to rerun before to debug it.
The file at_packagers_refresh_part2_index_tmp.txt is used during process, to resume processing only.

Note that data is incomplete for AT 70659 EG. Add manually:
    AT 70659 EG;Wildsammelstelle;Nauders;46.88999345167966;10.500373313796716


# POSTPROCESSING
- deactivate the virtual environment:
deactivate
- delete all temporary files
- update .sto file
'''

import camelot
import os
import polars as pl


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


def read_all_pdf() -> pl.dataframe.frame.DataFrame:
    # Directory containing PDF files
    pdf_directory = '.'

    # List to store DataFrames extracted from each PDF
    dfs = []

    # Loop through all PDF files in the directory
    for filename in os.listdir(pdf_directory):
        if filename.endswith('.pdf'):
            print(filename)
            # Extract tables from the PDF using Tabula
            pdf_path = os.path.join(pdf_directory, filename)
            try:
                # Extract tables from each PDF page
                tables = camelot.read_pdf(
                    pdf_path, pages='all', flavor="stream")

                file_dfs = []
                for table in tables:
                    df = pl.from_pandas(table.df)

                    # some rows have been split in 2 or 3
                    # to tackle it, 1) replace by the previous code when code is null
                    df_replace_null = df.with_columns(
                        pl.all().replace("", None))
                    df_fill_code = df_replace_null.with_columns(
                        pl.col("0").fill_null(strategy="forward"),)
                    # first row of the df are empty, select df without those
                    df_not_null = df_fill_code.filter(
                        pl.any_horizontal(pl.col("0").is_not_null()))
                    # 2) group by code and concat other columns
                    df_grouped_by_code = df_not_null.group_by('0').agg(
                        **{col: pl.col(col).str.concat(", ") for col in df.columns if col != '0'}
                    )

                    # ignore rows if first column does not start by "AT "
                    df = df_grouped_by_code.filter(
                        df_grouped_by_code['0'].str.starts_with("AT "))

                    # select col before concat because on some pages two columns
                    # are merged as a single one by the extraction
                    # resulting in different nb of columnes
                    # case column 0 & column 1 are merged (column 0 contains identification number: AT 61898 EG8007004)
                    column_1_suffix_check = df['0'].str.ends_with('EG').all()
                    if not column_1_suffix_check:
                        updated_col = df['0'].str.split(
                            "EG", inclusive=True).list.first()

                        # other columns are shifted
                        df = df.with_columns(updated_col.alias('0'), pl.col(
                            '2').alias('3'), pl.col('1').alias('2'))

                        column_1_suffix_double_check = df['0'].str.ends_with(
                            'EG').all()
                        if not column_1_suffix_double_check:
                            print("error parsing first column: ")
                            print(df.head(2))
                    # case column name (2) and column address (3) are merged
                    # example: KOPP ANGELIKA UND STEFAN\nEhringstraße 41, [WEINZIERL]\n9412 Wolfsberg,...
                    # the column 4 is always empty
                    if df.filter(pl.col('3') != '').is_empty():
                        # assume name1\naddres1, name2\naddress2, name3(\naddress3, name4)
                        df = df.with_columns(pl.col('2').map_elements(
                            lambda x: split_name_address(x, 'address'), return_dtype=str).alias('3'))
                        df = df.with_columns(pl.col('2').map_elements(
                            lambda x: split_name_address(x, 'name'), return_dtype=str).alias('2'))

                    df = df.select(['0', '2', '3'])

                    file_dfs.append(df)

                file_dfs_concat = pl.concat([file_df for file_df in file_dfs])
                file_dfs_concat.write_csv(filename + '.csv', separator=";")
                dfs.append(file_dfs_concat)

            except Exception as e:
                print(f"Error processing {pdf_path}: {e}")

    # Concatenate all DataFrames into a single DataFrame
    result_df = pl.concat(dfs)

    return result_df


def clean_name(input_name: str) -> str:
    # remove contact information
    input_name = "".join(input_name.split(', Tel.')[0])

    # remove repeated substrings
    substrings = input_name.split(', ')

    unique_substrings = []
    for substring in substrings:
        if substring not in unique_substrings:
            unique_substrings.append(substring)

    input_name = ', '.join(unique_substrings)

    # remove new line character
    input_name = input_name.replace('\n', ' ')

    # remove email addres at the end
    input_name = " ".join([i for i in input_name.split() if "@" not in i])
    input_name = input_name.strip(', ')

    # remove info in square bracket
    if '[' in input_name and ']' in input_name:
        input_name = input_name.split('[')[0].strip(', ')

    input_name = input_name.replace(',,', ',')
    input_name = input_name.replace(', ,', ',')

    return input_name


df = read_all_pdf()

new_column_names = ['code', 'name', 'address']
df_renamed = df.rename({i: j for i, j in zip(df.columns, new_column_names)})

df_clean_name = df_renamed.with_columns(
    pl.col('name').map_elements(lambda x: clean_name(x), return_dtype=str))

# rm duplicates
df_deduplicated = df_clean_name.unique()

df_deduplicated.write_csv('AT-merge-UTF-8_no_coord.csv', separator=';')
