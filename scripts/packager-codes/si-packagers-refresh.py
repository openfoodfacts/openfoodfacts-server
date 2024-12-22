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
apikey for geocode.maps.co (free account)

# INSTALLATION
## install virtual environment
sudo apt install python3.11-venv
python3 -m venv venv
source venv/bin/activate

## install needed packages
pip install polars
pip install requests


# FETCH INPUT FILE
# - from the Slovenian government website,
#   download the actual list of "Seznam odobrenih živilskih obratov"
#   (List of approved food establishments):
#   https://www.gov.si/zbirke/storitve/odobritev-zivilskega-obrata/
#   https://www.gov.si/assets/organi-v-sestavi/UVHVVR/Varna-hrana/Odobritev-obrata/Obrati-Zivila-O_ang.pdf
# - download last version of https://github.com/tabulapdf/tabula-java/releases
# - convert the pdf file into csv (update release number and file name):
# $ java -jar tabula-1.0.5-jar-with-dependencies.jar   Obrati-Zivila-O_ang.pdf \
#     --lattice --format CSV --pages all > slovenian_packaging_raw.csv

# RUN
update: api_key
python3 si-packagers-refresh.py

# POSTPROCESSING
- deactivate the virtual environment:
deactivate

delete cache.db file
'''

import polars as pl
import re
import requests
import sys
from time import sleep
import dbm
import json


file_name = "slovenian_packaging_raw.csv"
api_key = ""  # TODO remove
output_file_name = 'SI-merge-UTF-8.csv'


def clean_code(input_code: str) -> str:
    # remove double spaces
    input_code = input_code.replace('  ', ' ')

    # SI H-1015 ES
    if input_code.endswith('ES'):
        input_code = input_code.replace('ES', '').strip()

    # SI M-1035 SI
    if input_code.endswith('SI'):
        input_code = re.sub(r"\b(SI|ES)$", "", input_code).strip()

    # SI H-731, SI 731
    if ',' in input_code:
        input_code = "".join(input_code.split(', ')[1])

    # SI H - 728, SI H 728, SI H-728, also with M
    input_code = input_code.replace('H - ', 'H-')
    input_code = input_code.replace('H ', 'H-')
    input_code = input_code.replace('M - ', 'M-')
    input_code = input_code.replace('M ', 'M-')

    # SI - 907 -> SI 907
    input_code = input_code.replace(' - ', ' ')
    input_code = input_code.replace(' -', ' ')
    input_code = input_code.replace('SI-', 'SI ')

    # SI1194
    if 'SI ' not in input_code:
        input_code = input_code.replace('SI', 'SI ')
    # SI M1106
    if 'M-' not in input_code:
        input_code = input_code.replace('M', 'M-')

    return input_code


def clean_address(input_address: str) -> str:
    # special character because
    # sometimes new line between 2 addreses
    # sometimes line for single address split in 2
    input_address = "<>".join(input_address.split('\r'))

    # fetch last occurence
    # words 123A, place, 4567 city name
    # Á found in a city name (PROSENJAKOVCI -PÁRTOSFALVA)
    pattern = r'(([a-zčćžđšA-ZČĆŽĐŠŽ\s.-]+\d+[ABCDEFGIJ]?),(?:[a-zčćžđšA-ZČĆŽĐŠŽ\s\<\>.-]+,\s*)?[\<\>]*(\s*\d{4}[a-zčćžđšA-ZČĆŽĐŠŽÁ\s\<\>.-]+)$)'
    # SI M-316 - should be Fužinska Ulica 1, 4220 Škofja Loka - not Kidričeva Cesta 63A, 4220 Škofja Loka

    match = re.search(pattern, input_address)

    if match:
        output_address = (f"{match.group(2).strip().title()}, {
                          match.group(3).replace('<>', ' ').strip().title()}")
    else:
        # MOŠNJE , MOŠNJE, 4240 RADOVLJICA -> no street number (also DIJAŠKA ULICA , 5220 TOLMIN)
        # instead, fetch "something, postal_code city"
        pattern_2 = r'(([a-zčćžđšA-ZČĆŽĐŠŽ\s\-\.]+),(\s*\d{4})([a-zčćžđšA-ZČĆŽĐŠŽÁ\s\-\.\<\>]+)$)'
        match_2 = re.search(pattern_2, input_address)
        if match_2:
            output_address = (f"{match_2.group(2).strip().title()}, {
                              match_2.group(3).replace('<>', ' ').strip().title()}")
        else:
            print("Match problem", input_address)
            output_address = input_address

    return output_address


def cached_get(url: str, cache) -> list:
    # Check if the URL is already in the cache
    if url in cache:
        # If yes, return the cached response
        print(" from cache")
        return json.loads(cache[url])

    # restart 3 times in case of empty response to make sure it is not an issue in API-side
    restart = True
    i = 0
    while restart:
        # If not, make the HTTP request
        try:
            response = requests.get(url)
        except (requests.exceptions.RequestException, KeyError, IndexError) as e:
            return []
        data = response.json()
        if data == [] and i < 3:
            i += 1
            print("  restart ", i)
            sleep(1)
        else:
            restart = False

    # Store the JSON response in the cache
    cache[url] = json.dumps(data)

    return data


def convert_address_to_lat_lng(address_to_convert: str) -> str:
    # free plan: 1 request per second
    sleep(1)

    print("address_to_convert: ", address_to_convert)
    street, post_and_town = address_to_convert.split(',')
    postalcode = post_and_town.strip().split()[0]
    town = " ".join(post_and_town.strip().split()[1:])

    url = f"https://geocode.maps.co/search?street={street}&town={town}&postalcode={
        postalcode}&country=Slovenia&country_code=si&api_key={api_key}"

    with dbm.open('cache', 'c') as cache:
        data = cached_get(url, cache)
        if data != []:
            lat_lng = f"{data[0]['lat']},{data[0]['lon']}"
        else:
            sleep(1)
            # drop housenumber (example: Vrhpolje 1D, 5271 Vipava)
            url_2 = f"https://geocode.maps.co/search?street={' '.join(street.split()[:-1])}&town={
                town}&postalcode={postalcode}&country=Slovenia&country_code=si&api_key={api_key}"

            print(" try remove house number")

            data = cached_get(url_2, cache)

            if data != []:
                lat_lng = f"{data[0]['lat']},{data[0]['lon']}"
            else:
                sleep(1)
                # drop street (example: Gabrovlje 14, 3214 Zreče)
                url_3 = f"https://geocode.maps.co/search?town={town}&postalcode={
                    postalcode}&country=Slovenia&country_code=si&api_key={api_key}"

                print(" try remove street")

                data = cached_get(url_3, cache)

                if data != []:
                    lat_lng = f"{data[0]['lat']},{data[0]['lon']}"
                else:
                    print(f'Empty response for: {address_to_convert}')
                    sys.exit(1)

    return lat_lng


def main():
    if api_key == "":
        print("missing API key")
        sys.exit(1)

    df = pl.read_csv(file_name, separator=',')

    # keep only needed columns
    df_selected = df[:, [0, 1, 2]]

    # rename columns
    new_column_names = ['code', 'name', 'address']
    df_renamed = df_selected.rename(
        {i: j for i, j in zip(df_selected.columns, new_column_names)})

    # ignore rows if first column is "Approval No.", or if missing SI (sometimes just number or H + number)
    df_filtered_tmp = df_renamed.filter(
        df_renamed['code'].str.starts_with("SI"))
    df_filtered = df_filtered_tmp.with_columns(
        pl.col('code').map_elements(lambda x: clean_code(x), return_dtype=str))

    # first column keep only first row (second row tell about business, meat processing, for example)
    df_unique_name = df_filtered.with_columns(pl.col('name').map_elements(
        lambda x: "".join((x.split('\r')[0]).split(',')[0].title()), return_dtype=str))

    df_unique_address = df_unique_name.with_columns(
        pl.col('address').map_elements(lambda x: clean_address(x), return_dtype=str))

    # rm duplicates
    df_deduplicated = df_unique_address.unique()

    df_lat_lng = df_deduplicated.with_columns(pl.col("address").map_elements(
        lambda x: convert_address_to_lat_lng(x), return_dtype=str).alias("lat_lng"))

    # split in 2
    df_lat = df_lat_lng.with_columns(
        pl.col('lat_lng').str.split(',').list.get(0).alias('lat'))
    df_lng = df_lat.with_columns(
        pl.col('lat_lng').str.split(',').list.get(1).alias('lng'))

    df_final = df_lng.drop(['lat_lng'])

    df_final.write_csv(output_file_name, separator=';')


if __name__ == "__main__":
    main()
