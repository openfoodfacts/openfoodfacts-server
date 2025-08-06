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
'''

import csv
import requests
import re
import sys
from time import sleep
import dbm
import json


def extract_address_components(address_to_convert):
    '''
    split in a) number, street -> street
    b) postalcode
    and c) city

    remark: in Luxemburg, postalcode is used
    '''
    address_split = address_to_convert.split(',')

    address_split = [x.strip() for x in address_split]
    street, postalcode, city = ", ".join(
        address_split[:-2]), address_split[-2], address_split[-1]

    return street, postalcode, city


def cached_get(url: str, cache) -> list:
    print(f"cached_get, input: {url}")
    # Check if the URL is already in the cache
    if url in cache:
        # If yes, return the cached response
        print("cached_get, url exists in cache")
        return json.loads(cache[url])

    # restart 3 times in case of empty response to make sure it is not an issue in API-side
    restart = True
    i = 0
    while restart:
        # If not, make the HTTP request
        try:
            response = requests.get(url, headers=headers)
            # 1 request per second
            sleep(1)
        except (requests.exceptions.RequestException, KeyError, IndexError):
            return []

        if response.status_code == 403:
            print('cached_get, Queries on API are too frequents, increase sleep time')
            sys.exit(1)
        data = response.json()
        if data == [] and i < 3:
            i += 1
            print("cached_get,   restart ", i)
        else:
            restart = False

    # Store the JSON response in the cache
    cache[url] = json.dumps(data)

    return data


def no_results_update_query(url: str, i: int) -> str:
    print(f"no_results_update_query, input: {url}")
    if i == 1:
        url = re.sub("street=[^&]*&", "", url)
        print(f"no_results_update_query, remove street: {url}")
    elif i == 2:
        # replace SCHIFFLANGE/FOETZ by SCHIFFLANGE for city
        url = re.sub("city=([^/]*)/[^&]*&", "city=\\1&", url)
        print(f"no_results_update_query, remove city: {url}")
    elif i == 3:
        url = re.sub("city=[^&]*&", "", url)
        print(f"no_results_update_query, remove city: {url}")
    else:
        print(f"no_results_update_query, failing again, {url}")
        sys.exit(1)
    return url


def convert_address_to_lat_lng(address_to_convert: str) -> list:

    print(f"\ninfo, address_to_convert: {address_to_convert}")

    street, postalcode, city = extract_address_components(address_to_convert)

    url = "https://nominatim.openstreetmap.org/search.php?"

    if street:
        url += f"street={street}&"
    if postalcode:
        url += f"postalcode={postalcode}&"
    if city:
        url += f"city={city}&"

    url += f"country={country_name}&country_code={country_code}&format=jsonv2"

    failed = True
    iter_failures = 0
    while failed:
        with dbm.open('cache', 'c') as cache:
            data = cached_get(url, cache)
            if data != []:
                lat, lng = [data[0]['lat'], data[0]['lon']]
                failed = False
            else:
                iter_failures += 1
                url = no_results_update_query(url, iter_failures)

    return [lat, lng]


if __name__ == "__main__":
    country_code = 'LU'
    country_name = 'Luxembourg'
    source_file = f'{country_code}-merge-UTF-8_no_coord.csv'
    target_file = f'{country_code}-merge-UTF-8.csv'
    index_last_line_processed = f'{
        country_code.lower()}_packagers_refresh_part2_index_tmp.txt'

    # use user agent for requests
    headers = {'User-Agent': 'packager-openfoodfacts'}

    data = []
    try:
        with open(index_last_line_processed, 'r') as f:
            index = int(f.read())
    except FileNotFoundError:
        print(f"info, create temporary file {index_last_line_processed}")
        index = 0

    print(f"info, index is set to {index}")

    l = 0
    with open(source_file, mode='r', newline='') as csv_file_read:
        with open(target_file, mode='a', newline='') as csv_file_write:
            reader = csv.reader(csv_file_read, delimiter=";")
            writer = csv.writer(csv_file_write, delimiter=";")
            for row in reader:
                # continue previous run
                if l <= index and index != 0:
                    l += 1
                    continue
                # header
                elif l == 0:
                    row += ['lat', 'lng']
                else:
                    row += convert_address_to_lat_lng(row[2])

                writer.writerow(row)

                with open(index_last_line_processed, 'w') as f:
                    f.write(str(l))
                l += 1
