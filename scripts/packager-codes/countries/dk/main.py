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

"""
This script automatically:
1. Downloads the Excel file from the official website
    https://foedevarestyrelsen.dk/kost-og-foedevarer/start-og-drift-af-foedevarevirksomhed/autorisation-og-registrering/registrerede-og-autorisede-foedevarevirksomheder
   
   Target file format: "Autoriserede_Foedevarevirksomheder_Excel.xlsx"

2. Converts XLS to CSV
3. Removes header lines
4. Processes semi-colons and commas properly
5. Geocodes addresses using Nominatim OpenStreetMap API
6. Outputs final CSV with coordinates
  
Note: The script will automatically select the latest file matching "svi odobreni objekti".

How to fix:
 - set DEBUG to True
 - comment out 'cleanup_temp_files()' function to persist tmp files
 - run the code
 - find the packaging code where it fails
 - review the address (often due to typo in the city name or street name)
 - resume
"""

import sys

from common.config import load_config, save_config
from common.convert import convert_excel_to_csv, merge_csv_files
from common.download import download_excel_file
from common.geocode import geocode_csv
from common.io import generate_file_identifier, move_output_to_packager_codes, cleanup_temp_files
from countries.dk.transform import preprocess_csv_denmark

COUNTRY_NAME = 'Denmark'
COUNTRY_CODE = 'dk'
# DEBUG = False
DEBUG = True
SLEEP_DURATION = 2.0

def process_source_file(country_name: str, country_code: str, debug: bool, 
                       source_idx: int, file_idx: int, 
                       url: str, keyword: str, last_filename: str,
                       file_config: dict, source: dict, config: dict) -> bool:
    """
    Process a single file from a source.

    Args:
        country_name: Name of the country
        country_code: Country code
        debug: Debug flag
        source_idx: Index of the source
        file_idx: Index of the file
        url: URL of the source
        keyword: Keyword to identify the file
        last_filename: Last known filename
        file_config: Configuration for the file
        source: Source configuration
        config: Overall configuration
    
    Returns:
        True if processing was successful, False otherwise
    """
    file_id = generate_file_identifier(keyword, last_filename)

    excel_file = f'{country_code}_{file_id}_downloaded.xls'
    source_file = f'{country_code}_{file_id}_preprocessed.csv'
    target_file = f'{country_code.upper()}_{file_id}_merge.csv'
    
    print(f"\n{country_name} - Info - Processing file {file_idx + 1} from source {source_idx + 1}")
    print(f"{country_name} - Info - File identifier: {file_id}")

    try:
        # Step 1: Download Excel file
        # Searches for keyword (if provided), compares with last_filename, returns None if match (no update needed)
        new_filename = download_excel_file(country_name, url, excel_file, keyword=keyword, expected_file_name=last_filename)
        
        # If new_filename is None, file already processed - no update needed
        if new_filename is None and keyword:
            print(f"{country_name} - Info - File already up to date, skipping processing")
            return True
        
        # Get sheet range from config (default to single sheet 0 if not specified)
        sheets_config = file_config.get('sheets', {})
        sheet_start = sheets_config.get('start', 0)
        sheet_end = sheets_config.get('end', 0)
        
        csv_files = []
        for sheet_idx in range(sheet_start, sheet_end + 1):
            sheet_csv_raw_file = f'{country_code}_{file_id}_sheet{sheet_idx}_raw.csv'

            # Step 2: Convert Excel sheets to CSV (sheets 3-21, indices 2-20)
            convert_excel_to_csv(country_name, excel_file, sheet_csv_raw_file, sheet_index=sheet_idx)
        
            sheet_csv_preprocessed_file = f'{country_code}_{file_id}_sheet{sheet_idx}_preprocessed.csv'

            # Step 3: Preprocess CSV to standardized format
            preprocess_csv_denmark(country_name, sheet_csv_raw_file, sheet_csv_preprocessed_file)
        

            csv_files.append(sheet_csv_preprocessed_file)

        # Step 4: Merge all CSV files into one
        merge_csv_files(country_name, csv_files, source_file, skip_headers=True)
        
        # Step 5: Geocode addresses
        failure_count, total_count = geocode_csv(debug, country_name, country_code, source_file, target_file, SLEEP_DURATION)
        
        if failure_count > 0:
            raise RuntimeError(f"Geocoding failed for {failure_count} addresses out of {total_count}. All addresses must be successfully geocoded.")
        
        # Step 5: Move output to packager-codes directory
        move_output_to_packager_codes(country_name, country_code, target_file)
        
        # Step 6: Update configuration with new filename after successful processing
        if new_filename and new_filename != last_filename:
            file_config['last_filename'] = new_filename
            source['files'][file_idx] = file_config
            config[country_code]['sources'][source_idx] = source
            save_config(config)
            print(f"{country_name} - Info - Updated configuration with new filename: {new_filename}")
        
        return True
        
    except Exception as e:
        print(f"{country_name} - Error - Failed to process file: {e}")
        return False
        
    finally:
        cleanup_temp_files(country_name, [excel_file, source_file])


def main():
    """Main function to process Croatian packager codes CSV file."""
    
    print(f"\n{'='*60}")
    print(f"Packager Codes Geocoding Script: {COUNTRY_NAME} ({COUNTRY_CODE})")
    
    config = load_config()
    
    if COUNTRY_CODE not in config:
        print(f"{COUNTRY_NAME} - Error - No configuration found for country code '{COUNTRY_CODE}'")
        sys.exit(1)
    
    country_config = config[COUNTRY_CODE]
    sources = country_config['sources']
    
    total_sources = len(sources)
    successful_files = 0
    total_files = 0

    for source_idx, source in enumerate(sources):
        url = source['url']
        files_config = source.get('files', [])
        
        if not files_config:
            print(f"{COUNTRY_NAME} - Warning - No files configured for source {source_idx + 1}, skipping")
            continue
        
        print(f"\n{COUNTRY_NAME} - Info - Processing source {source_idx + 1}/{total_sources}: {url}")
        
        for file_idx, file_config in enumerate(files_config):
            keyword = file_config.get('keyword')
            last_filename = file_config.get('last_filename')
            
            total_files += 1
            
            success = process_source_file(
                COUNTRY_NAME, COUNTRY_CODE, DEBUG,
                source_idx, file_idx,
                url, keyword, last_filename,
                file_config, source, config
            )
            
            if success:
                successful_files += 1
    
    print(f"\n{'='*60}")
    print(f"{COUNTRY_NAME} - Summary - Processed {successful_files}/{total_files} files successfully")
    
    if successful_files == 0:
        print(f"{COUNTRY_NAME} - Error - No files were processed successfully")
        sys.exit(1)
