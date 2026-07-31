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
from urllib.parse import urlencode

from common.config import load_config
from common.download import cached_get
from common.io import write_csv
import common.geocode_strategies as strategies_module


CACHE_DB_BASE = 'geocode_cache'
CACHE_DB_EXTENSION = '.db'


def build_nominatim_url(params: dict) -> str:
    """
    Build Nominatim API URL from parameters.
    
    Args:
        params: Dictionary of query parameters
        
    Returns:
        Complete URL string
    """
    base_url = "https://nominatim.openstreetmap.org/search.php"
    query_string = urlencode({k: v for k, v in params.items() if v})
    return f"{base_url}?{query_string}"


def get_country_simplification_strategies(country_code: str, initial_params: dict = None):
    """
    Get country-specific simplification strategies from config.
    
    Args:
        country_code: ISO country code (e.g., 'fi', 'dk', 'hr')
        initial_params: Initial query parameters (needed for reset strategies)
    
    Returns:
        List of strategy functions
    """
    config = load_config()
    
    if country_code not in config:
        raise ValueError(f"Country code '{country_code}' not found in config")
    
    country_config = config[country_code]
    strategy_names = country_config.get('geocoding_strategies', [])
    
    if not strategy_names:
        # Default strategies if none configured
        strategy_names = [
            'strategy_split_street_comma',
            'strategy_remove_street',
            'strategy_remove_postalcode',
            'strategy_split_city_hyphen'
        ]
    
    # Convert strategy names to actual functions
    strategy_functions = []
    for name in strategy_names:
        if name.startswith('strategy_reset_without'):
            # Factory functions that need initial_params
            if name == 'strategy_reset_without_city':
                func = strategies_module.create_strategy_reset_without_city(initial_params)
            elif name == 'strategy_reset_without_country':
                func = strategies_module.create_strategy_reset_without_country(initial_params)
            else:
                raise ValueError(f"Unknown factory strategy: {name}")
        else:
            # Regular strategy functions
            func = getattr(strategies_module, name, None)
            if func is None:
                raise ValueError(f"Unknown strategy: {name}")
        
        strategy_functions.append(func)
    
    return strategy_functions


def convert_address_to_lat_lng(debug: bool, country_name: str, country_code: str, row: list, sleep_duration: float = 2.0) -> list:
    """
    Convert address from CSV row to latitude and longitude using Nominatim.
    
    We use a persistent cache, through dbm to avoid resolving known addresses.
    Args:
        debug: Enable debug logging
        country_name: Full country name (e.g., "Croatia")
        country_code: ISO country code (e.g., "hr")
        row: Standardized CSV row [code, name, street, city, postalcode]
        sleep_duration: Delay in seconds between API requests (default: 2.0)
        
    Returns:
        [latitude, longitude] as strings
    """

    cache_db = f"{CACHE_DB_BASE}_{country_code}{CACHE_DB_EXTENSION}"

    # Extract address components from standardized row
    # Columns: [0=code, 1=name, 2=street, 3=city, 4=postalcode]
    code = row[0] if len(row) > 0 else ""
    street = row[2] if len(row) > 2 else ""
    city = row[3] if len(row) > 3 else ""
    postalcode = row[4] if len(row) > 4 else ""

    # Build query parameters
    params = {
        'street': street,
        'city': city,
        'postalcode': postalcode,
        'country': country_name,
        'countrycodes': country_code,
        'format': 'jsonv2'
    }

    if debug:
        param_strings = []
        for key, value in params.items():
            if key == 'format':
                continue
            if not value:
                param_strings.append(f"{key}: NULL")
            else:
                param_strings.append(f"{key}: {value}")

        print(f"{country_name} - Debug - Starting geocode {code}: Params: {', '.join(param_strings)}")

    initial_params = params.copy()
    url = build_nominatim_url(params)

    if debug:
        print(f"{country_name} - Debug - {code}: Starting geocoding with initial URL: {url}")
    
    # Get country-specific strategies from config, passing initial_params
    strategies = get_country_simplification_strategies(country_code, initial_params)
    
    with dbm.open(cache_db, 'c') as cache:
        data = cached_get(debug, country_name, url, cache, sleep_duration)
        if data != []:
            lat, lng = [data[0]['lat'], data[0]['lon']]
            if debug:
                print(f"{country_name} - Debug - {code}: Successfully geocoded (lat={lat}, lng={lng})")
            return [lat, lng]
    
    for attempt, strategy_func in enumerate(strategies, start=1):
        print(f"{country_name} - Warning - {code}: No results found (attempt {attempt}/{len(strategies) + 1})")
        
        # Apply strategy to modify params
        modified_params = strategy_func(country_name, params, code)
        
        # Skip retry if strategy returned None (no modification made)
        if modified_params is None:
            if debug:
                print(f"{country_name} - Debug - {code}: Strategy made no changes, skipping retry")
            continue
        
        params = modified_params
        url = build_nominatim_url(params)
        
        if debug:
            print(f"{country_name} - Debug - {code}: Retrying with modified URL: {url}")
        
        with dbm.open(cache_db, 'c') as cache:
            data = cached_get(debug, country_name, url, cache, sleep_duration)
            if data != []:
                lat, lng = [data[0]['lat'], data[0]['lon']]
                if debug:
                    print(f"{country_name} - Debug - {code}: Successfully geocoded (lat={lat}, lng={lng})")
                return [lat, lng]
    
    address_info = f"street='{street}', city='{city}', postalcode='{postalcode}'"
    raise RuntimeError(f"{code}: Could not geocode after {len(strategies) + 1} attempts. Address: {address_info}. Final URL: {url}")


def geocode_csv(debug: bool, country_name: str, country_code: str, input_csv: str, output_csv: str, sleep_duration: float = 2.0) -> tuple:
    """
    Read preprocessed CSV and geocode all addresses.
    
    preprocessed CSV contains: code, name, street, city, postalcode
    
    Args:
        debug: Enable debug logging
        country_name: Full country name (e.g., "Croatia")
        country_code: ISO country code (e.g., "hr")
        input_csv: Path to the preprocessed CSV file
        output_csv: Path to write the geocoded CSV file
        sleep_duration: Delay in seconds between API requests (default: 2.0)
        
    Returns:
        Tuple of (failure_count, total_count)
    """
    print(f"{country_name} - Step - Geocoding addresses from {input_csv}")
    
    rows_output = []
    success_count = 0
    failure_count = 0
    failed_codes = []
    
    try:
        with open(input_csv, mode='r', newline='', encoding='utf-8') as csv_file_read:
            reader = csv.reader(csv_file_read, delimiter=";")
            
            for i, row in enumerate(reader):
                if i == 0:
                    row_output = row + ['lat', 'lng']
                    rows_output.append(row_output)
                else:
                    code = row[0] if len(row) > 0 else "Unknown"
                    
                    try:
                        lat_lng = convert_address_to_lat_lng(debug, country_name, country_code, row, sleep_duration)
                        
                        row_output = row + lat_lng
                        rows_output.append(row_output)
                        success_count += 1
                        
                        print(f"{country_name} - Info - {code} added successfully")
                        
                    except RuntimeError as e:
                        failure_count += 1
                        failed_codes.append(code)
                        print(f"{country_name} - Error - {code}: Failed to geocode (row {i}). {e}")
                        # Skip this row - do not add to output
                    
                    if i % 50 == 0:
                        print(f"{country_name} - Info - Processed {i} rows: {success_count} geocoded, {failure_count} failed")
    except FileNotFoundError as e:
        raise FileNotFoundError(f"Source file '{input_csv}' not found") from e
    except Exception as e:
        raise RuntimeError(f"Error reading source file: {e}") from e
    
    write_csv(country_name, output_csv, rows_output)
    
    total_count = success_count + failure_count
    print(f"{country_name} - Info - Geocoding complete. Total: {total_count}, Success: {success_count}, Failed: {failure_count}")
    
    if failure_count > 0:
        print(f"{country_name} - Warning - Failed codes: {', '.join(failed_codes[:10])}" + (" ..." if len(failed_codes) > 10 else ""))
    
    return (failure_count, total_count)

