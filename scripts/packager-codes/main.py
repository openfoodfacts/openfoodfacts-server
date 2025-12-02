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
import sys
import argparse

from common.config import load_config, save_config
from common.convert import merge_csv_files
from common.geocode import geocode_csv
from common.io import generate_file_identifier, move_output_to_packager_codes, cleanup_temp_files, find_preprocessed_csv_files, find_temporary_files
from common.processors import process_excel_file, process_html_file

DEBUG = False
SLEEP_DURATION = 2.0


def process_source_file(country_name: str, country_code: str, 
                       source_idx: int, file_idx: int, 
                       url: str, keyword: str, last_filename: str,
                       file_config: dict) -> tuple:
    """
    Process a single file from a source (dispatcher based on file type).

    Args:
        country_name: Name of the country
        country_code: Country code
        source_idx: Index of the source
        file_idx: Index of the file
        url: URL of the source
        keyword: Keyword to identify the file
        last_filename: Last known filename
        file_config: Configuration for the file
    
    Returns:
        Tuple of (success: bool, new_filename: str or None)
    """
    file_id = generate_file_identifier(keyword, last_filename)
    
    print(f"\n{country_name} - Info - Processing file {file_idx + 1} from source {source_idx + 1}")
    print(f"{country_name} - Info - File identifier: {file_id}")

    file_type = file_config.get('type')
    if not file_type:
        raise ValueError(f"Missing 'type' field in file configuration for {file_id}")
    
    try:
        if file_type == 'excel':
            return process_excel_file(country_name, country_code, url, keyword, last_filename,
                                     file_config, file_id)
        elif file_type == 'html':
            return process_html_file(country_name, country_code, url, keyword, last_filename,
                                    file_config, file_id)
        else:
            raise ValueError(f"Unknown file type '{file_type}' for file {file_id}")
        
    except Exception as e:
        print(f"{country_name} - Error - Failed to process file: {e}")
        return False, None


def process_country(country_code: str):
    """Process packager codes for a single country."""
    
    config = load_config()
    
    if country_code not in config:
        print(f"Error - No configuration found for country code '{country_code}'")
        sys.exit(1)
    
    country_config = config[country_code]
    country_name = country_config.get('country_name', 'Unknown')
    
    print(f"\n{'='*60}")
    print(f"Packager Codes Geocoding Script: {country_name} ({country_code})")
    sources = country_config['sources']
    
    total_sources = len(sources)
    successful_files = 0
    total_files = 0
    updated_filenames = []  # Track updated filenames for config update
    merged_file = f'{country_code}_preprocessed_merged.csv'
    target_file = f'{country_code}_target.csv'

    try:
        for source_idx, source in enumerate(sources):
            url = source['url']
            files_config = source.get('files', [])
            
            if not files_config:
                print(f"{country_name} - Warning - No files configured for source {source_idx + 1}, skipping")
                continue
            
            print(f"\n{country_name} - Info - Processing source {source_idx + 1}/{total_sources}: {url}")
            
            for file_idx, file_config in enumerate(files_config):
                keyword = file_config.get('keyword')
                last_filename = file_config.get('last_filename')
                
                total_files += 1
                
                success, new_filename = process_source_file(
                    country_name, country_code,
                    source_idx, file_idx,
                    url, keyword, last_filename,
                    file_config
                )
                
                if success:
                    successful_files += 1
                    # Track filename updates for config
                    if new_filename and new_filename != last_filename:
                        updated_filenames.append((source_idx, file_idx, new_filename))
        
        # Find all preprocessed CSV files created during processing
        print(f"\n{country_name} - Info - Finding all preprocessed CSV files")
        preprocessed_csv_files = find_preprocessed_csv_files(country_code)
        
        if not preprocessed_csv_files:
            print(f"{country_name} - Info - No new files to process (all files already up to date)")
            print(f"{country_name} - Info - Skipping geocoding step")
            return
        
        print(f"{country_name} - Info - Found {len(preprocessed_csv_files)} preprocessed CSV files")
        
        # Merge all preprocessed CSV files
        merge_csv_files(country_name, preprocessed_csv_files, merged_file, skip_headers=True)
        
        # Geocode addresses
        failure_count, total_count = geocode_csv(DEBUG, country_name, country_code, merged_file, target_file, SLEEP_DURATION)
        
        if failure_count > 0:
            raise RuntimeError(f"Geocoding failed for {failure_count} addresses out of {total_count}. All addresses must be successfully geocoded.")
        
        # Move output to packager-codes directory
        move_output_to_packager_codes(country_name, country_code, target_file)
        
        # Update configuration with new filenames after successful processing
        if updated_filenames:
            for source_idx, file_idx, new_filename in updated_filenames:
                config[country_code]['sources'][source_idx]['files'][file_idx]['last_filename'] = new_filename
                print(f"{country_name} - Info - Updated configuration with new filename: {new_filename}")
            save_config(config)
    
    finally:
        if not DEBUG:
            # Cleanup all temporary files
            all_temp_files = find_temporary_files(country_code)
            cleanup_temp_files(country_name, all_temp_files)
    
    print(f"\n{'='*60}")
    print(f"{country_name} - Summary - Processed {successful_files}/{total_files} files successfully")
    
    if successful_files == 0:
        print(f"{country_name} - Error - No files were processed successfully")
        sys.exit(1)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Process packager codes for one or more countries.'
    )
    parser.add_argument(
        'countries',
        nargs='+',
        help='Country code(s) to process (e.g., dk fi hr)'
    )
    
    args = parser.parse_args()
    
    # Process each country
    for country_code in args.countries:
        try:
            process_country(country_code.lower())
        except Exception as e:
            print(f"\nError processing {country_code}: {e}")
            sys.exit(1)


if __name__ == '__main__':
    main()
