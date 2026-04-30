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

from common.convert import convert_excel_to_csv, merge_csv_files
from common.download import download_excel_file
from common.transform import preprocess_csv


def process_excel_file(country_name: str, country_code: str, 
                      url: str, keyword: str, last_filename: str,
                      file_config: dict, file_id: str) -> tuple:
    """
    Process an Excel file: download, convert to CSV, preprocess.
    
    Args:
        country_name: Name of the country
        country_code: Country code
        url: URL of the source
        keyword: Keyword to identify the file
        last_filename: Last known filename
        file_config: Configuration for the file
        file_id: Generated file identifier
    
    Returns:
        Tuple of (success: bool, new_filename: str or None)
    """
    excel_file = f'{country_code}_{file_id}_downloaded.xls'
    source_file = f'{country_code}_{file_id}_preprocessed.csv'
    
    # Step 1: Download Excel file
    new_filename = download_excel_file(country_name, url, excel_file, keyword=keyword, expected_file_name=last_filename)
    
    # If new_filename is None, file already processed - no update needed
    if new_filename is None and keyword:
        print(f"{country_name} - Info - File already up to date, skipping processing")
        return True, None
    
    # Get sheet range from config (default to single sheet 0 if not specified)
    sheets_config = file_config.get('sheets', {})
    sheet_start = sheets_config.get('start', 0)
    sheet_end = sheets_config.get('end', 0)
    
    csv_files = []
    for sheet_idx in range(sheet_start, sheet_end + 1):
        sheet_csv_raw_file = f'{country_code}_{file_id}_sheet{sheet_idx}_raw.csv'

        # Step 2: Convert Excel sheets to CSV
        convert_excel_to_csv(country_name, excel_file, sheet_csv_raw_file, sheet_index=sheet_idx)
    
        sheet_csv_preprocessed_file = f'{country_code}_{file_id}_sheet{sheet_idx}_preprocessed.csv'

        # Step 3: Preprocess CSV to standardized format using generic function
        preprocess_csv(country_name, country_code, sheet_csv_raw_file, sheet_csv_preprocessed_file, file_config)
    
        csv_files.append(sheet_csv_preprocessed_file)

    # Step 4: Merge all CSV files into one
    merge_csv_files(country_name, csv_files, source_file, skip_headers=True)
    
    return True, new_filename

def process_html_file(country_name: str, country_code: str,
                     url: str, keyword: str, last_filename: str,
                     file_config: dict, file_id: str) -> tuple:
    """
    Process HTML tables: scrape, extract data, preprocess.
    
    Args:
        country_name: Name of the country
        country_code: Country code
        url: URL of the source
        keyword: Keyword to identify the file
        last_filename: Last known filename
        file_config: Configuration for the file
        file_id: Generated file identifier
    
    Returns:
        Tuple of (success: bool, new_filename: str or None)
    """
    raise NotImplementedError("HTML processing not yet implemented")
