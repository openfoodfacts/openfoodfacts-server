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
import re
import requests
import sys
from time import sleep


def extract_address_components(address_to_convert):
    address_split = address_to_convert.split(',')
    address_split = [x.strip() for x in address_split]

    street = None
    postal_code = None
    town = None

    if address_split == [""]:
        print("warning, missing address")
    elif len(address_split) < 2:
        # can be postal code and town without comma
        # example: 281 63 Přehvozdí 62/2
        if address_split[0][:5].isdigit():
            print(
                "warning, address without street name (only postcode and town):", address_split)
            post_and_town = address_split[0]
            postal_code = post_and_town.split()[0]
            town = " ".join(post_and_town.split()[1:])
        elif address_split[0][:6].replace(" ", "").isdigit():
            print(
                "warning, address without street name (only postcode and town):", address_split)
            post_and_town = address_split[0]
            postal_code = " ".join(post_and_town.split()[:2])
            town = " ".join(post_and_town.split()[2:])
        else:
            print("warning, address is missing comma, set as town:", address_split)
            # assume it is town name only
            # remove prefix words without uppercase as first letter
            # Example: průmyslová zóna Kožlany
            if address_split[0].lower() != address_split[0]:
                all_words = address_split[0].split()
                updated_town = []
                found_title_word = False
                for w in all_words:
                    if w.lower() != w or found_title_word:
                        updated_town.append(w)

                # can be none
                # example: parc.č. 164 - zemědělský areál
                if updated_town:
                    town = updated_town

    elif len(address_split) == 2:
        street, post_and_town = address_split[0].strip(
        ), address_split[1].strip()
        # sometimes there are no postcode, just town
        if post_and_town[:5].isdigit():
            postal_code = post_and_town.split()[0]
            town = " ".join(post_and_town.split()[1:])
        elif post_and_town[:6].replace(" ", "").isdigit():
            postal_code = post_and_town[:6]
            town = post_and_town[6:]
        else:
            print(
                "warning: could not extract postal code, set second element as town", address_split)
            town = post_and_town

    else:
        print("info: more than 2 comma", address_split)
        # first element of the address split by comma contains digit
        if any(char.isdigit() for char in address_split[0]):
            street = address_split[0]
        # other elements of the address split by comma contains digit and are not postcode
        # street and number can be second or third
        elif any(char.isdigit() for char in address_split[1]) and not any([address_split[1][:5].isdigit(), address_split[1][:6].replace(" ", "").isdigit()]):
            street = address_split[1]
        elif any(char.isdigit() for char in address_split[2]) and not any([address_split[1][:5].isdigit(), address_split[1][:6].replace(" ", "").isdigit()]):
            street = address_split[2]
        else:
            print("warning, could not extract street", address_split)
            street = None

        # start from the end
        for i in range(len(address_split)-1, -1, -1):
            # strip to remove space after comma
            address_chunk = address_split[i].strip()

            if address_chunk[:5].isdigit():
                postal_code = address_chunk[:5]
                town = address_chunk[5:]
                break
            # can be at the end also
            # example: Podbořany 44101,Podbořany,Vroutecká 230
            elif address_chunk[-5:].isdigit():
                postal_code = address_chunk[-5:]
                town = address_chunk[:-5]
                break
            elif address_chunk[:6].replace(" ", "").isdigit():
                postal_code = address_chunk[:6]
                town = address_chunk[6:]
                break
            elif address_chunk[-6:].replace(" ", "").isdigit():
                postal_code = address_chunk[-6:]
                town = address_chunk[:-6]
                break

    # remove digit at the end of town
    # example: "Praha 20" -> Praha"
    if town:
        town = "".join([c for c in town if c.isalpha() or c.isspace()]).strip()
    else:
        print("error, town undefined, lat and lng will be search for the country only.")

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
        url += f"town={town}&"
    if postal_code:
        url += f"postal_code={postal_code}&"
    url += f"country=Czechia&country_code=cz&api_key={api_key}"

    try:
        print(f"url_1 {url}")
        response = requests.get(url)
        data = response.json()
        if data != []:
            lat, lng = data[0]['lat'], data[0]['lon']
        else:
            sleep(1)
            # drop additional number or number (example: Podlanig 3 /1)
            old_street = street
            street_split = street.split("/")

            # number can be Roman numeral (example: Jiráskovo předměstí 638/III)
            is_roman_numeral = True
            for c in street_split[-1]:
                if c.lower() not in ['i', 'v', 'x']:
                    is_roman_numeral = False
                    break

            if street_split[-1].isdigit() or is_roman_numeral:
                street = " ".join(street_split[0:-1])

            # drop abbreviations (example: Příšovice č. p. 177)
            # (?<!^) -> prevent first word to be dropped
            if "." in street[1:-1]:
                pattern = r"(?<!^)(^|(?<=\s))\S+\. (?=|$)"
                street = re.sub(pattern, "", street)

            # drop duplicated street name
            # example: hotecká 1538 1538/1538 -> hotecká 1538 1538 (previously)
            # hotecká 1538 1538 -> hotecká 1538 (hereafter)
            pattern = r"(\d+)\s*\1\b"
            street = re.sub(pattern, r"\1", street)

            if old_street != street:
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


if __name__ == "__main__":
    source_file = 'CZ-merge-UTF-8_no_coord.csv'
    target_file = "CZ-merge-UTF-8.csv"
    index_last_line_processed = 'cz_packagers_refresh_part2_index_tmp.txt'
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
                # print(row)
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
