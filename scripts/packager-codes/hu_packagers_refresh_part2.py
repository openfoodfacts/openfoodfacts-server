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
import sys
from time import sleep


def extract_address_components(address_to_convert):
    address_split = address_to_convert.split(',')
    address_split = [x.strip() for x in address_split]

    street = None
    postal_code = None
    town = None
    post_and_town = None

    if address_split == [""]:
        print("warning, missing address")
    elif len(address_split) < 2:
        print("info, address without comma")
        post_and_town = address_split[0].strip()

    elif len(address_split) == 2:
        print("info, exactly 1 comma", address_split)
        # postcode and town are first
        post_and_town, street = address_split[0].strip(
        ), address_split[1].strip()
    else:
        print("info, more than 1 comma", address_split)

    if post_and_town:
        # type 626 Harta -> 6326 Harta
        if '626 Harta' in post_and_town:
            post_and_town = post_and_town.replace('626 Harta', '6326 Harta')
        if post_and_town[:4].isdigit():
            postal_code = post_and_town[:4]
            town = post_and_town[5:]
        # sometimes spaces between all characters
        # 2 0 2 4  K i s o r o s z i
        elif post_and_town.replace(' ', '')[:4].isdigit():
            postal_code = post_and_town.replace(' ', '')[:4]
            town_no_space = post_and_town.replace(' ', '')[4:]
            town = ""
            for ch in town_no_space:
                if ch.isupper() and town != "":
                    town += f" {ch}"
                else:
                    town += ch
        else:
            print(
                "warning, could not extract postal code, set whole element as town", post_and_town)
            town = post_and_town

    print(f"street: {street}, postal_code: {postal_code}, town: {town}")
    return street, postal_code, town


def convert_address_to_lat_lng(address_to_convert: str) -> list:
    # free plan: 1 request per second
    sleep(1)

    print(f"\ninfo, address_to_convert: {address_to_convert}")

    street, postal_code, town = extract_address_components(address_to_convert)

    url = "https://geocode.maps.co/search?"
    if street:
        url += f"street={street}&"
    if town:
        url += f"city={town}&"
    if postal_code:
        url += f"postalcode={postal_code}&"
    url += f"country={country_name}&country_code={country_code}&api_key={api_key}"

    try:
        print(f"url_1 {url}")
        response = requests.get(url)
        data = response.json()
        if data != []:
            lat, lng = data[0]['lat'], data[0]['lon']
        else:
            sleep(1)
            url_2 = url.replace(f"street={street}&", "")
            print("info, drop street")

            try:
                print("url_2", url_2)
                response = requests.get(url_2)
                data = response.json()
                if data != []:
                    lat, lng = data[0]['lat'], data[0]['lon']
                else:
                    sleep(1)

                    # drop city
                    url_3 = url_2.replace(f"city={town}&", "")
                    print("info, drop town")

                    try:
                        print("url_3", url_3)
                        response = requests.get(url_3)
                        data = response.json()
                        if data != []:
                            lat, lng = data[0]['lat'], data[0]['lon']
                        else:
                            sleep(1)

                            # postalcode typo
                            # 8927 Nemessándorháza -> 8925 Nemessándorháza
                            url_4 = url_3.replace(
                                f"postalcode={postal_code}", f"city={town}")
                            print("info, replace postalcode by town")

                            try:
                                print("url_4", url_4)
                                response = requests.get(url_4)
                                data = response.json()
                                if data != []:
                                    lat, lng = data[0]['lat'], data[0]['lon']
                                else:
                                    print(f'Empty response for: {
                                          address_to_convert}, {url_4}')
                                    sys.exit(1)
                            except (requests.exceptions.RequestException, KeyError, IndexError) as e:
                                print(f"Error: {e}, url: {url}")
                                sys.exit(1)
                    except (requests.exceptions.RequestException, KeyError, IndexError) as e:
                        print(f"Error: {e}, url: {url}")
                        sys.exit(1)
            except (requests.exceptions.RequestException, KeyError, IndexError) as e:
                print(f"Error: {e}, url: {url}")
                sys.exit(1)
    except (requests.exceptions.RequestException, KeyError, IndexError) as e:
        print(f"Error: {e}, url: {url}")
        sys.exit(1)

    return [lat, lng]


if __name__ == "__main__":
    country_code = 'HU'
    country_name = 'Hungary'
    source_file = f'{country_code}-merge-UTF-8_no_coord.csv'
    target_file = f'{country_code}-merge-UTF-8.csv'
    index_last_line_processed = f'{
        country_code.lower()}_packagers_refresh_part2_index_tmp.txt'
    api_key = ""  # TODO remove

    data = []
    try:
        with open(index_last_line_processed, 'r') as f:
            index = int(f.read())
    except FileNotFoundError as e:
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
