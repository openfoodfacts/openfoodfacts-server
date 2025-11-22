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
import re
from typing import List, Tuple, Optional

from common.config import load_text_replacements


def normalize_text(text: str, country_code: str) -> str:
    """
    Normalize text: expand abbreviations, fix typos, clean up formatting.
    
    Args:
        text: The text to normalize
        country_code: ISO country code (e.g., 'hr', 'de', 'fr')
        
    Returns:
        Normalized text
    """
    if not text:
        return text
    
    # Load replacements once per country code (cached at function attribute level)
    cache_key = f'_replacements_{country_code}'
    if not hasattr(normalize_text, cache_key):
        setattr(normalize_text, cache_key, load_text_replacements(country_code))
    
    replacements = getattr(normalize_text, cache_key)
    
    for pattern, replacement in replacements.items():
        text = re.sub(pattern, replacement, text, flags=re.IGNORECASE)
    
    return text.strip()


def get_data_rows(rows: List[List[str]], header_keywords: Optional[List[str]] = None) -> Tuple[List[List[str]], int]:
    """
    Extract data rows from CSV by finding header row using keywords.
    
    The idea is that there might be other data above the header row,
    so it will skip those lines and the header line.
    
    Args:
        rows: All rows from CSV
        header_keywords: Keywords to identify header row (e.g., ['broj', 'naziv']).
                        If None, assumes no header (all rows are data).
                        If provided, header MUST be found or raises ValueError.
    
    Returns:
        Tuple of (data_rows_without_header, expected_column_count)
        
    Raises:
        ValueError: If header_keywords provided but no matching header found
    """
    if not rows:
        return ([], 0)
    
    if header_keywords is None:
        expected_cols = len(rows[0]) if rows else 0
        return (rows, expected_cols)
    
    header_idx = None
    for idx, row in enumerate(rows[:10]):
        row_text = ' '.join(str(cell) for cell in row).lower()
        if all(keyword.lower() in row_text for keyword in header_keywords):
            header_idx = idx
            break
    
    if header_idx is None:
        raise ValueError(f"Header row not found with keywords: {header_keywords}")
    
    expected_cols = len(rows[header_idx])
    data_rows = rows[header_idx + 1:]
    
    return (data_rows, expected_cols)
