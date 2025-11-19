"""
This file is part of Product Opener.

Product Opener
Copyright (C) 2011-2025 Association Open Food Facts
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
"""
import csv
import dbm
import re
import sys

from common.download import cached_get
from common.io import write_csv


CACHE_DB_BASE = 'geocode_cache'


def no_results_update_query(country_name: str, url: str, i: int, code: str) -> str:
    """
    Update query URL when no results are found by removing components.
    
    Args:
        url: The original URL
        i: Iteration counter (1-3)
        code: The establishment code for logging
        
    Returns:
        Modified URL with component removed
    """    
    if i == 1:
        # Remove street parameter
        print(f"{country_name} - Warning - {code}: failed with following url: {url}. Retrying without street")
        url = re.sub(r"street=[^&]*&", "", url)
    elif i == 2:
        # Remove postalcode parameter
        print(f"{country_name} - Warning - {code}: failed with following url: {url}. Retrying without postalcode")
        url = re.sub(r"postalcode=[^&]*&", "", url)
    else:  # i == 3
        # If city has hyphen, keep only first part (e.g., Satnica-Petrijevci -> Satnica)
        print(f"{country_name} - Warning - {code}: failed with following url: {url}. Retrying with simplified city name (before hyphen)")
        city_match = re.search(r"city=([^&]*)", url)
        if city_match:
            city_value = city_match.group(1)
            if '-' in city_value:
                simplified_city = city_value.split('-')[0]
                url = re.sub(r"city=[^&]*", f"city={simplified_city}", url)
        
    return url


def convert_address_to_lat_lng(debug: bool, country_name: str, country_code: str, row: list) -> list:
    """
    Convert address from CSV row to latitude and longitude using Nominatim.
    
    Args:
        debug: Enable debug logging
        country_name: Full country name (e.g., "Croatia")
        country_code: ISO country code (e.g., "hr")
        row: Standardized CSV row [code, name, street, city, postalcode]
        
    Returns:
        [latitude, longitude] as strings
    """

    cache_db = f"{CACHE_DB_BASE}_{country_code}"

    # Extract address components from standardized row
    # Columns: [0=code, 1=name, 2=street, 3=city, 4=postalcode]
    code = row[0] if len(row) > 0 else ""
    street = row[2] if len(row) > 2 else ""
    city = row[3] if len(row) > 3 else ""
    postalcode = row[4] if len(row) > 4 else ""

    url = "https://nominatim.openstreetmap.org/search.php?"

    if street:
        url += f"street={street}&"
    if city:
        url += f"city={city}&"
    if postalcode:
        url += f"postalcode={postalcode}&"

    url += f"country={country_name}&countrycodes={country_code}&format=jsonv2"

    if debug:
        print(f"{country_name} - Debug - {code}: Starting geocoding with initial URL")
    
    failed = True
    iter_failures = 0
    while failed:
        with dbm.open(cache_db, 'c') as cache:
            data = cached_get(debug, country_name, url, cache)
            if data != []:
                lat, lng = [data[0]['lat'], data[0]['lon']]
                if debug:
                    print(f"{country_name} - Debug - {code}: Successfully geocoded (lat={lat}, lng={lng})")
                failed = False
            else:
                iter_failures += 1
                print(f"{country_name} - Warning - {code}: No results found (attempt {iter_failures}/3)")
                if iter_failures <= 3:
                    url = no_results_update_query(country_name, url, iter_failures, code)
                    if debug:
                        print(f"{country_name} - Debug - {code}: Retrying with modified URL: {url}")
                else:
                    # Fail if all attempts fail
                    print(f"{country_name} - Error - {code}: Could not geocode after {iter_failures} attempts. Final URL was: {url}")
                    sys.exit(1)

    return [lat, lng]


def geocode_csv(debug: bool, country_name: str, country_code: str, input_csv: str, output_csv: str):
    """
    Read preprocessed CSV and geocode all addresses.
    
    proprocessed CSV contains: code, name, street, city, postalcode
    
    Args:
        debug: Enable debug logging
        country_name: Full country name (e.g., "Croatia")
        country_code: ISO country code (e.g., "hr")
        input_csv: Path to the preprocessed CSV file
        output_csv: Path to write the geocoded CSV file
    """
    print(f"{country_name} - Step - Geocoding addresses from {input_csv}")
    
    rows_output = []
    success_count = 0
    
    try:
        with open(input_csv, mode='r', newline='', encoding='utf-8') as csv_file_read:
            reader = csv.reader(csv_file_read, delimiter=";")
            
            for i, row in enumerate(reader):
                if i == 0:
                    row_output = row + ['lat', 'lng']
                    rows_output.append(row_output)
                else:
                    code = row[0] if len(row) > 0 else "Unknown"
                    
                    lat_lng = convert_address_to_lat_lng(debug, country_name, country_code, row)
                    
                    row_output = row + lat_lng
                    rows_output.append(row_output)
                    success_count += 1
                    
                    print(f"{country_name} - Info - {code} added successfully")
                    
                    if i % 50 == 0:
                        print(f"{country_name} - Info - Processed {i} rows: {success_count} geocoded")
    except FileNotFoundError:
        print(f"{country_name} - Error - Source file '{input_csv}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"{country_name} - Error - Reading source file: {e}")
        sys.exit(1)
    
    write_csv(country_name, output_csv, rows_output)
    
    print(f"{country_name} - Info - Geocoding complete. Total rows geocoded: {success_count}")

