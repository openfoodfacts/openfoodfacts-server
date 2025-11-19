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
import pandas as pd

def convert_excel_to_csv(country_name: str, excel_file: str, csv_file: str):
    """
    Convert Excel file to CSV format.
    
    Args:
        excel_file: Path to the Excel file
        csv_file: Path where to save the CSV file
    """
    print(f"{country_name} - Step - Converting Excel {excel_file} to CSV {csv_file}")
    
    try:
        # Try different engines in case one fails
        df = None
        for engine in ['openpyxl', 'xlrd']:
            try:
                df = pd.read_excel(excel_file, engine=engine, header=None)
                break
            except Exception as e:
                print(f"{country_name} - Warning - Failed to read Excel with {engine} engine: {e}")
                continue
        if df is None:
            raise RuntimeError("Could not read Excel file with any engine")
        
        df.to_csv(csv_file, index=False, header=False, encoding='utf-8')

        print(f"{country_name} - Info - Converted to CSV: {csv_file} (rows: {len(df)}, columns: {len(df.columns)})")
        
    except Exception as e:
        raise RuntimeError(f"Failed to convert Excel to CSV: {e}") from e
