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
    address_to_convert = address_to_convert.replace(',,', ',')
    address_split = address_to_convert.split(',')
    address_split = [x.strip() for x in address_split]

    street = None
    postal_code = None
    town = None

    if address_split == [""]:
        print("warning missing address")
    elif len(address_split) < 2:
        if address_split[0][:4].isdigit():
            print(
                "warning address without street name (only postcode and town):", address_split[0])
            post_and_town = address_split[0]
            if "," in post_and_town:
                postal_code = post_and_town.split()[0]
                town = " ".join(post_and_town.split()[1:])
            else:
                town = address_split[0]
        else:
            print("warning address is missing comma:", address)
            town = address_split[0]

    elif len(address_split) == 2:
        street, post_and_town = address_split[0], address_split[1]
        # sometimes there are no postcode, just town
        if post_and_town[:4].isdigit():
            postal_code = post_and_town.split()[0]
            town = " ".join(post_and_town.split()[1:])
        else:
            town = post_and_town
    else:
        if any(char.isdigit() for char in address_split[0]):
            street = address_split[0]
        # street and number can be second or third
        elif any(char.isdigit() for char in address_split[1]) and not address_split[1][:4].isdigit():
            street = address_split[1]
        elif any(char.isdigit() for char in address_split[2]) and not address_split[2][:4].isdigit():
            street = address_split[2]
        # street and street number can be split
        elif address_split[1].isdigit() and len(address_split[1]) != 4:
            street = f"{address_split[0]} {address_split[1]}"
        else:
            print("error to parse street:", address)
            street = None

        # post_and_town can be last or fore-last
        if address_split[-1][:4].isdigit():
            post_and_town = address_split[-1]
            postal_code = post_and_town.split()[0]
            town = " ".join(post_and_town.split()[1:])
        elif address_split[-2][:4].isdigit():
            post_and_town = address_split[-2]
            postal_code = post_and_town.split()[0]
            town = " ".join(post_and_town.split()[1:])
        else:
            print("error to extract postcode and town:", address)

    return street, postal_code, town


def convert_address_to_lat_lng(address_to_convert: str) -> list:
    # at least one code without address: Wildsammelstelle Nauders
    if address_to_convert == "":
        return ","
    # free plan: 1 request per second
    sleep(1)

    print("address_to_convert: ", address_to_convert)

    street, postal_code, town = extract_address_components(address_to_convert)

    url = "https://geocode.maps.co/search?"
    if street:
        url += f"street={street}&"
    if town:
        url += f"town={town}&"
    if postal_code:
        url += f"postal_code={postal_code}&"
    url += f"country=Austria&country_code=at&api_key={api_key}"

    try:
        response = requests.get(url)
        print(response.status_code)
        data = response.json()
        if data != []:
            lat, lng = data[0]['lat'], data[0]['lon']
        else:
            sleep(1)
            # drop additional number or number (example: Podlanig 3 /1)
            old_street = street
            street_split = street.replace("/", " ").split()
            street_split = [x for x in street_split if x != ""]
            if street_split[-1].isdigit():
                street = " ".join(street_split[0:-1])
                url_2 = url.replace(old_street, street)
            # drop street
            else:
                url_2 = url.replace(f"street={old_street}&", "")

            try:
                print("url_2", url_2)
                response = requests.get(url_2)
                data = response.json()
                if data != []:
                    lat, lng = data[0]['lat'], data[0]['lon']
                else:
                    sleep(1)
                    # drop street (example: Gabrovlje 14, 3214 Zreče)
                    if street in url_2:
                        url_3 = url_2.replace(f"street={street}&", "")
                    else:
                        print(f'Empty response for before url_3: {
                              address_to_convert}: {url_2}')
                        sys.exit(1)

                    try:
                        print("url_3", url_3)
                        response = requests.get(url_3)
                        data = response.json()
                        if data != []:
                            lat, lng = data[0]['lat'], data[0]['lon']
                        else:
                            print(f'Empty response for: {
                                  address_to_convert}" {url_3}')
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


source_file = 'AT-merge-UTF-8_no_coord.csv'
target_file = "AT-merge-UTF-8.csv"
index_last_line_processed = 'at_packagers_refresh_part2_index_tmp.txt'
api_key = ""  # TODO remove


data = []
try:
    with open(index_last_line_processed, 'r') as f:
        index = int(f.read())
except FileNotFoundError as e:
    print(f"Create temporary file {index_last_line_processed}")
    index = 0

print(index)

l = 0
with open(source_file, mode='r', newline='') as csv_file_read:
    with open(target_file, mode='a', newline='') as csv_file_write:
        reader = csv.reader(csv_file_read, delimiter=";")
        writer = csv.writer(csv_file_write, delimiter=";")
        for row in reader:
            print(row)
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
