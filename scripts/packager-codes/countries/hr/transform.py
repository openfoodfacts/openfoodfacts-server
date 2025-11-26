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
import re

from common.config import load_config
from common.csv_utils import get_data_rows, normalize_text
from common.io import write_csv

config = load_config()
HEADER_KEYWORDS = [k.lower() for k in config['hr']['header_keywords']]

def is_valid_approval_code(code: str) -> bool:
    """
    Check if a code is a valid approval number (not header text).
    
    Valid codes are numeric (possibly with letters/hyphens): "2", "123", "456-A"
    Invalid: empty, header text, contains spaces/slashes, doesn't start with digit
    
    Args:
        code: The code to validate
        
    Returns:
        True if valid approval code, False otherwise
    """    
    code_lower = code.lower().rstrip('.').strip()
    if not code_lower or not code_lower[0].isdigit():
        return False
    
    # Check if code is actually a header keyword
    if code_lower in HEADER_KEYWORDS:
        return False
    
    return True


def extract_city_and_postal(city_and_postalcode: str) -> tuple:
    """
    Extract city and postal code from combined string.
    
    Croatian format: "City Name, 12345" or "Region, City, 12345"
    
    Args:
        city_and_postalcode: Combined string with city and optional postal code
        
    Returns:
        Tuple of (city, postalcode)
    """
    city = ""
    postalcode = ""
    
    # Try to extract postal code (5 digits, may have spaces like "21 217")
    postalcode_match = re.search(r'\b(\d[\s\d]{0,4}\d)\b', city_and_postalcode)
    
    if postalcode_match:
        postal_candidate = postalcode_match.group(1).replace(' ', '')
        # Check if it's exactly 5 digits after removing spaces
        if len(postal_candidate) == 5 and postal_candidate.isdigit():
            postalcode = postal_candidate
            # Remove postal code and clean up
            city_temp = re.sub(r'\b\d[\s\d]{0,4}\d\b', '', city_and_postalcode, count=1).strip(' ,')
            # Take last element after comma (actual city name)
            city = city_temp.split(',')[-1].strip() if ',' in city_temp else city_temp
        else:
            # Not a valid postal code
            city = city_and_postalcode.split(',')[-1].strip() if ',' in city_and_postalcode else city_and_postalcode.strip()
    else:
        # No postal code found
        city = city_and_postalcode.split(',')[-1].strip() if ',' in city_and_postalcode else city_and_postalcode.strip()
    
    return (city, postalcode)


def preprocess_csv_croatia(country_name: str, input_csv: str, output_csv: str):
    """
    Preprocess the Croatian CSV file to standardized format.
    
    Output columns: code, name, street, city, postalcode
    
    Steps:
    1. Remove first N lines before header
    2. Extract and normalize columns from Croatian format
    3. Transform code to 'HR {code} EU' format
    4. Extract address components
    5. Write standardized output
    
    Args:
        country_name: Full country name
        input_csv: Path to the input CSV file
        output_csv: Path to the output CSV file with standardized columns
    """
    print(f"{country_name} - Step - Preprocessing CSV {input_csv} to {output_csv}")
    try:
        output_rows = []
        
        with open(input_csv, 'r', encoding='utf-8', newline='') as f:
            reader = csv.reader(f, delimiter=',')
            all_rows = list(reader)
        
        # 1. Use generic CSV detection with Croatian-specific header keywords
        data_rows, expected_columns = get_data_rows(all_rows, HEADER_KEYWORDS)
        
        print(f"{country_name} - Info - Detected table structure: {expected_columns} columns, {len(data_rows)} data rows")

        # 2. Write standardized header
        header = ['code', 'name', 'street', 'city', 'postalcode']
        output_rows.append(header)

        # 3. Process data rows
        for row in data_rows:
            # Clean cell values
            row = [cell.replace(';', ',').replace('"', '').strip() for cell in row]
            
            # Croatian CSV format (11 columns total):
            # 0: row number (will be ignored), 1: approval code, 2: name, 3: street, 4: city+postal
            if len(row) < 5:
                continue
            
            raw_code = row[1]
            if not is_valid_approval_code(raw_code):
                continue
            
            code = f"HR {raw_code} EU"
            name = row[2]
            street = row[3]
            
            # 4. Extract address components
            city, postalcode = extract_city_and_postal(row[4])
            
            street = normalize_text(street, 'hr')
            city = normalize_text(city, 'hr')
            
            standardized_row = [code, name, street, city, postalcode]
            output_rows.append(standardized_row)
        
        # 5. Write with semicolon delimiter
        write_csv(country_name, output_csv, output_rows)

        print(f"{country_name} - Info - Preprocessed CSV Croatia saved: {output_csv} (rows: {len(output_rows)})")
        
    except Exception as e:
        raise RuntimeError(f"Failed to preprocess CSV Croatia: {e}") from e
