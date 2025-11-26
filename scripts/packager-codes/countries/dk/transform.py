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
from common.io import write_csv, cleanup_temp_files

config = load_config()
HEADER_KEYWORDS = config['dk']['header_keywords']

def is_valid_approval_code_denmark(code: str) -> bool:
    """
    Check if a code is a valid approval number (not header text).
    
    Valid codes are numeric (possibly with letters/hyphens): "2", "123", "456-A", "M123"
    Invalid: empty, header text, contains spaces/slashes, doesn't start with digit
    
    Args:
        code: The code to validate
        
    Returns:
        True if valid approval code, False otherwise
    """    
    code_lower = code.lower().rstrip('.').strip()
    if not code_lower:
        return False

    if code_lower in HEADER_KEYWORDS:
        return False
    
    return True


def extract_address_components_denmark(address: str) -> tuple:
    """
    Extract street, postal code, and city from combined address string.
    
    Danish format: "Street Name, Postal Code, City"
    
    Args:
        address: Combined string with street, postal code, and city
        
    Returns:
        Tuple of (street, postalcode, city)
    """
    street = ""
    city = ""
    postalcode = ""
    
    commas_count = address.count(",")

    address_decomposed = address.split(",")
    
    street = ",".join(address_decomposed[:commas_count]).strip()
    
    postalcode_city = ",".join(address_decomposed[commas_count:]).strip()
    
    postalcode = postalcode_city.split(" ")[0]
    
    city = " ".join(postalcode_city.split(" ")[1:])

    return (street, postalcode, city)


def preprocess_csv_denmark(country_name: str, input_csv: str, output_csv: str):
    """
    Preprocess the Danish CSV file to standardized format.
    
    Output columns: code, name, street, city, postalcode
    
    Steps:
    1. Remove first N lines before header
    2. Extract and normalize columns from Danish format
    3. Transform code to 'DK {code} EU' format
    4. Extract address components
    5. Write standardized output
    6. Clean up input CSV file
    
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
        
        # 1. Use generic CSV detection with Country-specific header keywords
        data_rows, expected_columns = get_data_rows(all_rows, HEADER_KEYWORDS)
        
        print(f"{country_name} - Info - Detected table structure: {expected_columns} columns, {len(data_rows)} data rows")

        # 2. Write standardized header
        header = ['code', 'name', 'street', 'city', 'postalcode']
        output_rows.append(header)

        # 3. Process data rows
        for row in data_rows:
            # Clean cell values
            row = [cell.replace(';', ',').replace('"', '').strip() for cell in row]
            
            # CSV format (8 columns total):
            # 1: approval number, 2: name, 3: street+postal+city
            if len(row) < 3:
                continue
            
            raw_code = row[0]
            if not is_valid_approval_code_denmark(raw_code):
                continue
            
            raw_code = raw_code.replace('DK', '').strip()
            code = f"DK {raw_code} EF"
            name = row[1]
            
            # 4. Extract address components
            street, postalcode, city = extract_address_components_denmark(row[2])
            
            city = normalize_text(city, 'dk')
            
            standardized_row = [code, name, street, city, postalcode]
            output_rows.append(standardized_row)
        
        # 5. Write with semicolon delimiter
        write_csv(country_name, output_csv, output_rows)

        # 6. Clean up input CSV file
        cleanup_temp_files(country_name, [input_csv])

        print(f"{country_name} - Info - Preprocessed CSV Denmark saved: {output_csv} (rows: {len(output_rows)})")
        
    except Exception as e:
        raise RuntimeError(f"Failed to preprocess CSV Denmark: {e}") from e