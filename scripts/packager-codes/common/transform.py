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

from common.csv_utils import get_data_rows, normalize_text
from common.io import write_csv, cleanup_temp_files


def is_valid_approval_code(code: str, header_keywords: list) -> bool:
    """
    Generic validation for approval codes (works for all countries).
    
    Valid codes must contain at least one digit: "2", "123", "456-A", "M123", "DK4772"
    Invalid: empty, header text, text without numbers
    
    Args:
        code: The code to validate
        header_keywords: List of header keywords to exclude
        
    Returns:
        True if valid approval code, False otherwise
    """    
    code_lower = code.lower().rstrip('.').strip()
    if not code_lower:
        return False

    # Check if code is actually a header keyword
    if code_lower in header_keywords:
        return False
    
    # Must contain at least one digit to be a valid approval code
    if not any(char.isdigit() for char in code_lower):
        return False
    
    return True


def format_approval_code(raw_code: str, country_code: str, code_config: dict) -> str:
    """
    Format approval code with country prefix and suffix.
    
    Args:
        raw_code: Raw code from source
        country_code: Two-letter country code (FI, DK, HR)
        code_config: Configuration dict with:
            - strip_prefix: Optional prefix to remove (e.g., "DK" for Denmark)
            - suffix: Suffix to add (EC, EF, EU)
            
    Returns:
        Formatted code: "{COUNTRY_CODE} {code} {suffix}"
    """
    code = raw_code
    
    # Remove prefix if specified
    strip_prefix = code_config.get('strip_prefix')
    if strip_prefix and code.upper().startswith(strip_prefix.upper()):
        code = code[len(strip_prefix):].strip()
    
    suffix = code_config.get('suffix', 'EC')
    return f"{country_code.upper()} {code} {suffix.upper()}"


def extract_address(row: list, columns: dict) -> dict:
    """
    Extract address from separate columns (default).
    
    Args:
        row: CSV row data
        columns: Column mapping dict with keys: street, city, postalcode
        
    Returns:
        Dict with keys: street, city, postalcode
    """
    return {
        'street': row[columns['street']],
        'city': row[columns['city']],
        'postalcode': row[columns['postalcode']]
    }


def extract_address_street_postalcode_city(row: list, columns: dict) -> dict:
    """
    Extract address from combined "street, postalcode, city" format.
    
    Format: "Street Name, Postal Code, City"
    
    Args:
        row: CSV row data
        columns: Column mapping dict with key: street_postalcode_city
        
    Returns:
        Dict with keys: street, city, postalcode
    """
    address = row[columns['street_postalcode_city']]
    
    commas_count = address.count(",")
    address_decomposed = address.split(",")
    
    street = ",".join(address_decomposed[:commas_count]).strip()
    postalcode_city = ",".join(address_decomposed[commas_count:]).strip()
    
    postalcode = postalcode_city.split(" ")[0]
    city = " ".join(postalcode_city.split(" ")[1:])
    
    return {
        'street': street,
        'city': city,
        'postalcode': postalcode
    }


def extract_address_city_and_postalcode(row: list, columns: dict) -> dict:
    """
    Extract address from format with combined city_and_postalcode.
    
    Format: "City Name, 12345" or "Region, City, 12345"
    
    Args:
        row: CSV row data
        columns: Column mapping dict with keys: street, city_and_postalcode
        
    Returns:
        Dict with keys: street, city, postalcode
    """
    city_and_postalcode = row[columns['city_and_postalcode']]
    
    # Try to extract postal code (5 digits, may have spaces like "21 217")
    postalcode_match = re.search(r'\b(\d[\s\d]{0,4}\d)\b', city_and_postalcode)
    
    city = ""
    postalcode = ""
    
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
    
    return {
        'street': row[columns['street']],
        'city': city,
        'postalcode': postalcode
    }


# Registry of address extraction strategies
ADDRESS_EXTRACTORS = {
    'street_postalcode_city': extract_address_street_postalcode_city,
    'city_and_postalcode': extract_address_city_and_postalcode
}


def preprocess_csv(country_name: str, country_code: str, input_csv: str, 
                          output_csv: str, file_config: dict):
    """
    Generic CSV preprocessing for all countries.
    
    Output columns: code, name, street, city, postalcode
    
    Configuration (from file_config):
    - columns: Column indices mapping
    - header_keywords: Keywords to detect header row
    - code_format: Dict with 'strip_prefix' and 'suffix'
    - address_extractor: Optional strategy name ('street_postalcode_city', 'city_and_postalcode'). If not specified, uses default separate column extraction.
    - normalize_fields: List of field names to normalize (e.g., ['street', 'city', 'code'])
    - postalcode_format: Optional dict with 'zfill' for zero-padding
    
    Args:
        country_name: Full country name
        country_code: Two-letter country code
        input_csv: Path to input CSV file
        output_csv: Path to output CSV file
        file_config: Configuration dictionary for the file
    """
    print(f"{country_name} - Step - Preprocessing CSV {input_csv} to {output_csv}")
    try:
        # Get configuration
        columns = file_config.get('columns', {})
        if not columns:
            raise ValueError("No column mappings found in file configuration")
        
        header_keywords = [k.lower() for k in file_config.get('header_keywords', [])]
        if not header_keywords:
            raise ValueError("No header keywords found in file configuration")
        
        code_config = file_config.get('code_format', {'suffix': 'EC'})
        address_extractor_name = file_config.get('address_extractor')
        normalize_fields = file_config.get('normalize_fields', [])
        postalcode_format = file_config.get('postalcode_format', {})
        
        # Get address extractor function (default to extract_address if not specified)
        if address_extractor_name:
            if address_extractor_name not in ADDRESS_EXTRACTORS:
                raise ValueError(f"Unknown address extractor: {address_extractor_name}")
            address_extractor = ADDRESS_EXTRACTORS[address_extractor_name]
        else:
            address_extractor = extract_address
        
        output_rows = []
        
        # Read CSV
        with open(input_csv, 'r', encoding='utf-8', newline='') as f:
            reader = csv.reader(f, delimiter=',')
            all_rows = list(reader)
        
        # Detect data rows
        data_rows, expected_columns = get_data_rows(all_rows, header_keywords)
        print(f"{country_name} - Info - Detected table structure: {expected_columns} columns, {len(data_rows)} data rows")

        # Write standardized header
        header = ['code', 'name', 'street', 'city', 'postalcode']
        output_rows.append(header)

        # Process data rows
        for row in data_rows:
            # Clean cell values
            row = [cell.replace(';', ',').replace('"', '').replace("'", "").strip() for cell in row]
            
            # Check minimum row length, a row should contain at least the number of columns provided in columns mapping
            # a count lower than that indicates an incomplete row (row in 2 lines, for example), bottom of page text, etc.
            min_col_index = max(columns.values())
            if len(row) <= min_col_index:
                continue
            
            # Extract and validate code
            raw_code = row[columns['code']]
            # Normalize code if requested
            if 'code' in normalize_fields:
                raw_code = normalize_text(raw_code, country_code.lower())
            
            if not is_valid_approval_code(raw_code, header_keywords):
                continue
            
            code = format_approval_code(raw_code, country_code, code_config)
            
            # Extract name
            name = row[columns['name']]
            
            # Extract address components using strategy
            address = address_extractor(row, columns)
            
            # Normalize fields as configured
            for field in normalize_fields:
                if field in address:
                    address[field] = normalize_text(address[field], country_code.lower())
            
            # Format postal code if needed
            postalcode = address['postalcode']
            if postalcode and 'zfill' in postalcode_format:
                # Validate that postal code is numeric before formatting
                if not postalcode.isdigit():
                    print(f"{country_name} - Warning - Skipping row with non-numeric postal code '{postalcode}' for code {code}")
                    continue
                postalcode = postalcode.zfill(postalcode_format['zfill'])
            
            standardized_row = [code, name, address['street'], address['city'], postalcode]
            output_rows.append(standardized_row)
        
        # Write output
        write_csv(country_name, output_csv, output_rows)

        # Clean up input CSV file
        cleanup_temp_files(country_name, [input_csv])

        print(f"{country_name} - Info - Preprocessed CSV saved: {output_csv} (rows: {len(output_rows)})")
        
    except Exception as e:
        raise RuntimeError(f"Failed to preprocess CSV: {e}") from e
