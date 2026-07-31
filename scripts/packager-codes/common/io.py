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
import os
import shutil
from pathlib import Path

# Go up from common/ -> packager-codes/ -> scripts/ -> repo_root, then to packager-codes/
PACKAGER_CODES_DIR = Path(__file__).parent.parent.parent.parent / 'packager-codes'


def generate_file_identifier(keyword: str = None, last_filename: str = None) -> str:
    """
    Generate a unique identifier for temporary files based on keyword or filename.
    
    Args:
        keyword: The keyword used to search for the file
        last_filename: The last known filename
        
    Returns:
        A sanitized identifier string
    """
    if keyword:
        # Use keyword, sanitize for filename (remove spaces, special chars)
        identifier = keyword.replace(' ', '_').replace('/', '_').replace('\\', '_')
        # Limit length and remove non-alphanumeric except underscore
        identifier = ''.join(c for c in identifier if c.isalnum() or c == '_')[:30]
        return identifier.lower()
    elif last_filename:
        # Extract base name without extension
        import os
        base = os.path.splitext(last_filename)[0]
        identifier = base.replace(' ', '_').replace('.', '_').replace('-', '_')
        identifier = ''.join(c for c in identifier if c.isalnum() or c == '_')[:30]
        return identifier.lower()
    else:
        # Fallback to generic identifier
        return 'unknown'


def write_csv(country_name: str, output_file: str, rows: list):
    """
    Write rows to CSV file.
    
    Args:
        country_name: Full country name
        output_file: Path to the output CSV file
        rows: List of rows to write
    """
    print(f"{country_name} - Step - Writing output to {output_file}")
    
    try:
        with open(output_file, mode='w', newline='', encoding='utf-8') as csv_file_write:
            writer = csv.writer(csv_file_write, delimiter=";")
            writer.writerows(rows)
        print(f"{country_name} - Info - Successfully wrote {len(rows)} rows to {output_file}")
    except Exception as e:
        raise RuntimeError(f"Failed to write output file: {e}") from e


def move_output_to_packager_codes(country_name: str, country_code: str, target_file: str):
    """
    Move final output file to packager-codes directory.
    
    Args:
        country_name: Full country name
        country_code: ISO country code
        target_file: The output file to move
    """
    if not os.path.exists(target_file):
        raise FileNotFoundError(f"Output file {target_file} not found")
    
    PACKAGER_CODES_DIR.mkdir(parents=True, exist_ok=True)
    
    final_name = f"{country_code.upper()}-merge-UTF-8.csv"
    
    target_file_path = PACKAGER_CODES_DIR / final_name
    
    shutil.copy2(target_file, target_file_path)
    print(f"{country_name} - Info - Copied {target_file} to {target_file_path}")
    
    os.remove(target_file)


def find_preprocessed_csv_files(country_code: str) -> list:
    """
    Find preprocessed CSV files for a country code (excludes merged and target files).
    These are the per-file preprocessed CSVs that need to be merged.
    
    Args:
        country_code: Country code (e.g., 'fi', 'dk', 'hr')
    
    Returns:
        List of preprocessed CSV file paths
    """
    import glob
    pattern = f"{country_code}_*_preprocessed.csv"
    csv_files = glob.glob(pattern)
    return csv_files


def find_temporary_files(country_code: str) -> list:
    """
    Find all temporary files for a country code (CSV and Excel).
    This includes all intermediate files for cleanup.
    
    Args:
        country_code: Country code (e.g., 'fi', 'dk', 'hr')
    
    Returns:
        List of temporary file paths that match the pattern
    """
    import glob
    temp_files = []
    # Find all CSV files
    temp_files.extend(glob.glob(f"{country_code}*.csv"))
    # Find all Excel files (xls and xlsx)
    temp_files.extend(glob.glob(f"{country_code}*.xls"))
    temp_files.extend(glob.glob(f"{country_code}*.xlsx"))
    return temp_files


def cleanup_temp_files(country_name: str, temp_files: list = None):
    """
    Remove temporary files created during processing.
    
    Args:
        country_name: Full country name
        temp_files: List of temporary file paths to remove (optional)
    """
    if temp_files is None:
        temp_files = []
    
    for temp_file in temp_files:
        if os.path.exists(temp_file):
            try:
                os.remove(temp_file)
                print(f"{country_name} - Info - Cleaned up temporary file: {temp_file}")
            except Exception as e:
                print(f"{country_name} - Warning - Could not remove {temp_file}: {e}")

