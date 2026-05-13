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


counties_list = ["antrim", "armagh", "carlow", "cavan", "clare", "cork",
                 "donegal", "down", "dublin", "fermanagh", "galway",
                 "kerry", "kildare", "kilkenny", "laois", "leitrim",
                 "limerick", "londonderry", "longford", "louth", "mayo",
                 "meath", "monaghan", "offaly", "roscommon", "sligo",
                 "tipperary", "tyrone", "waterford", "westmeath",
                 "wexford", "wicklow"]


def possible_county_check(possible_field: str) -> str:
    # examples: Dublin 17, Dublin12, Dublin22, Co. Dublin, Dublin 8., Co. Dublin.

    possible_field = possible_field.strip('.')

    # drop digit(s) at then end of the county
    if not possible_postcode_check(possible_field):
        match = re.search(r"\d+$", possible_field)
        if match:
            possible_field = possible_field[:match.start()]
        possible_field = possible_field.strip()

    extracted_county = possible_field.lower().replace(
        'co. ', '').replace('co.', '').replace('co ', '')
    if extracted_county in counties_list:
        return extracted_county.title()
    else:
        return ''


def possible_postcode_check(field: str) -> bool:
    # examples: D24 NY84, X35 Y670, P51A525, D22 E6P4
    field = field.replace(' ', '')
    if len(field) < 7:
        return False
    postcode_bool = all([field[0].isalpha(), field[1:3].isdigit(
    ), field[3].isalpha(), field[4:6].isalnum(), field[6:].isdigit()])
    return postcode_bool


def missing_comma_check_update_county(possible_county, updated_field):
    if updated_field and updated_field[-1].lower() in ['co', 'co.']:
        updated_field[-1] = f",{updated_field[-1]} {possible_county},"
    else:
        updated_field.append(f"{possible_county}")


def missing_comma_check_update_postcode_with_space(updated_field, i):
    if all([updated_field[-1][0].isalpha(), updated_field[-1][1:].isdigit()]):
        i = f"{updated_field[-1]} {i}"
        updated_field.pop(-1)


def missing_comma_check_update_postcode_without_space(updated_field, i):
    updated_field.append(f"{i},")


def missing_comma_check(field: str) -> str:
    # examples: Co Cork P85AT89, Dungarvan Co. Waterford X35 Y670
    print(f"missing_comma_check, input: {field}")
    decomposed = field.split()
    print(f"missing_comma_check, split: {decomposed}")
    updated_field = []
    for i in decomposed:
        print(f"missing_comma_check, loop element: {
              i}, updated field: {updated_field}")
        possible_county = possible_county_check(i)
        if possible_county:
            missing_comma_check_update_county(possible_county, updated_field)
            continue

        if updated_field and updated_field[-1] and len(updated_field[-1]) == 3 and len(i) == 4:
            missing_comma_check_update_postcode_with_space(updated_field, i)
            continue

        if possible_postcode_check(i):
            missing_comma_check_update_postcode_without_space(updated_field, i)
            continue

        updated_field.append(i)

    print(f"missing_comma_check, before join: {updated_field}")
    updated_field = " ".join(updated_field)
    print(f"missing_comma_check, after join: {updated_field}")
    updated_field = updated_field.strip(',')
    print(f"missing_comma_check, after strip: {updated_field}")

    return updated_field


def extract_address_components_one_comma(address_components: list) -> tuple:
    # can be
    #  - city and county
    #  - street and city

    # - city and county
    possible_county = possible_county_check(address_components[1])
    if possible_county:
        # street, city, county
        return '', address_components[0], possible_county
    # street and city
    else:
        # street, city, county
        return address_components[0], address_components[1], ''


def extract_address_components_two_commas(address_components: list) -> tuple:
    # can be
    #  - street, city, county
    #  - city, county, postcode

    #  - street, city, county
    possible_county_two = possible_county_check(address_components[2])
    if possible_county_two:
        # street, city, county
        return address_components[0], address_components[1], possible_county_two

    #  - city, county, postcode
    possible_county_one = possible_county_check(address_components[1])
    if possible_county_one:
        # ignore postcode
        # street, city, county
        return '', address_components[0], possible_county_one

    # other cases are not expected
    else:
        print('error. extract_address_components_two_commas, could not parse address with 2 commas')
        sys.exit(1)


def extract_address_components_more_than_two_commas(address_components: list) -> tuple:
    # start from the end and
    # assign county if found,
    # ignore additional county if found,
    # ignore postcode if found,
    # ignore 'Ireland' if found

    street = ''
    city = ''
    county = ''

    for i in range(1, len(address_components)+1):
        possible_county = possible_county_check(address_components[-i])
        possible_postcode = possible_postcode_check(address_components[-i])
        if possible_county and not county:
            county = possible_county
            continue

        # example: Quinlan Steele, Milleens Cheese ltd., Eyeries, Beara, Co.Cork, Ireland, P75 FN52
        if address_components[-i].lower() == 'ireland':
            continue

        if not possible_county and not possible_postcode:
            if not city:
                city = address_components[-i]
            elif not street:
                street = address_components[-i]
            else:
                print(f"info, extract_address_components_more_than_two_commas, already extracted everything, ignore: {
                      address_components[-i]}")

    return street, city, county


def extract_address_components(address_to_convert):
    address_split = address_to_convert.split(',')
    # handle cases like Co Cork P85AT89 -> Co Cork, P85AT89 (Ireland)
    address_split_with_sublist = [missing_comma_check(
        i).split(',') for i in address_split]
    address_split = [
        item for sublist in address_split_with_sublist for item in sublist]
    print(f"extract_address_components, address_split after missing comma check: {
          address_split}")

    address_split = [x.strip() for x in address_split]
    print(f"extract_address_components, address_split after strip elements: {
          address_split}")

    street = ''
    city = ''
    county = ''

    if address_split == [""]:
        print("error, extract_address_components, missing address")
        sys.exit(1)
    elif len(address_split) == 1:
        print("info, extract_address_components, address without comma")
        city = address_split[0]
    elif len(address_split) == 2:
        print("info, extract_address_components, exactly 1 comma")
        street, city, county = extract_address_components_one_comma(
            address_split)
    elif len(address_split) == 3:
        print("info, extract_address_components, contains 2 commas")
        street, city, county = extract_address_components_two_commas(
            address_split)
    else:
        print("info, extract_address_components, more than 2 commas")
        street, city, county = extract_address_components_more_than_two_commas(
            address_split)

    print(f"street: {street}, city: {city}, county: {county}")
    return street, city, county


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
        url = re.sub("city=[^&]*&", "", url)
        print(f"no_results_update_query, remove city: {url}")
    else:
        print(f"no_results_update_query, failing again, {url}")
        sys.exit(1)
    return url


def convert_address_to_lat_lng(address_to_convert: str) -> list:

    print(f"\ninfo, address_to_convert: {address_to_convert}")

    street, city, county = extract_address_components(address_to_convert)

    url = "https://nominatim.openstreetmap.org/search.php?"

    if street:
        url += f"street={street}&"
    if city:
        url += f"city={city}&"
    if county:
        url += f"county={county}&"
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
    country_code = 'IE'
    country_name = 'Ireland'
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
