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
import pandas as pd


def convert_excel_to_csv(country_name: str, excel_file: str, csv_file: str, sheet_index: int = 0):
    """
    Convert Excel file to CSV format.
    
    Args:
        country_name: Name of the country for logging
        excel_file: Path to the Excel file
        csv_file: Path where to save the CSV file
        sheet_index: Sheet index (0-based) to read (default: 0 for first sheet)
    """
    print(f"{country_name} - Step - Converting Excel {excel_file} (sheet {sheet_index}) to CSV {csv_file}")
    
    try:
        # Try different engines in case one fails
        df = None
        for engine in ['openpyxl', 'xlrd']:
            try:
                df = pd.read_excel(excel_file, engine=engine, sheet_name=sheet_index, header=None)
                break
            except Exception as e:
                print(f"{country_name} - Warning - Failed to read Excel with {engine} engine: {e}")
                continue
        if df is None:
            raise RuntimeError("Could not read Excel file with any engine")
        
        # Replace newlines within cells with spaces to prevent row splitting
        # This handles cases where Excel cells contain line breaks
        df = df.replace(to_replace=[r'\n', r'\r\n', r'\r'], value=' ', regex=True)
        
        # Save with proper quoting - use QUOTE_NONNUMERIC to quote all non-numeric fields
        # This ensures that fields with special characters are properly quoted
        df.to_csv(csv_file, index=False, header=False, encoding='utf-8', 
                  quoting=csv.QUOTE_NONNUMERIC)

        print(f"{country_name} - Info - Converted to CSV: {csv_file} (rows: {len(df)}, columns: {len(df.columns)})")
        
    except Exception as e:
        raise RuntimeError(f"Failed to convert Excel to CSV: {e}") from e


def merge_csv_files(country_name: str, csv_files: list, output_file: str, skip_headers: bool = True):
    """
    Merge multiple CSV files into a single CSV file.
    
    Final file as no duplicates and is sorted by code.
    
    Args:
        country_name: Name of the country for logging
        csv_files: List of CSV file paths to merge
        output_file: Path where to save the merged CSV file
        skip_headers: If True, skip the first row of each file after the first (default: True)
    """
    print(f"{country_name} - Step - Merging {len(csv_files)} CSV files into {output_file}")
    
    try:
        total_rows = 0
        with open(output_file, 'w', encoding='utf-8', newline='') as outfile:
            writer = None
            
            for idx, csv_file in enumerate(csv_files):
                with open(csv_file, 'r', encoding='utf-8', newline='') as infile:
                    reader = csv.reader(infile)
                    
                    for row_idx, row in enumerate(reader):
                        # Skip header rows for files after the first one
                        if skip_headers and idx > 0 and row_idx == 0:
                            continue
                        
                        if writer is None:
                            writer = csv.writer(outfile)
                        
                        writer.writerow(row)
                        total_rows += 1
        
        print(f"{country_name} - Info - Merged CSV saved: {output_file} (total rows: {total_rows})")
        
        # Remove duplicates and sort by code column
        print(f"{country_name} - Step - Removing duplicates from {output_file}")
        df = pd.read_csv(output_file, encoding='utf-8', delimiter=';', dtype=str, keep_default_na=False)
        original_count = len(df)
        df_deduplicated = df.drop_duplicates(keep='first')
        duplicates_removed = original_count - len(df_deduplicated)
        
        if duplicates_removed > 0:
            print(f"{country_name} - Info - Removed {duplicates_removed} duplicate rows")
        else:
            print(f"{country_name} - Info - No duplicates found")
        
        # Sort by code column alphabetically
        if 'code' in df_deduplicated.columns:
            print(f"{country_name} - Step - Sorting by code column")
            df_deduplicated = df_deduplicated.sort_values(by='code', key=lambda x: x.str.lower())
        
        # Save with quoting to prevent any conversion issues
        df_deduplicated.to_csv(output_file, index=False, encoding='utf-8', sep=';', quoting=csv.QUOTE_MINIMAL)
        
    except Exception as e:
        raise RuntimeError(f"Failed to merge CSV files: {e}") from e
