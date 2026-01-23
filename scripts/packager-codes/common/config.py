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
import json
import re

CONFIG_FILE = 'packager_sources_config.json'
TEXT_REPLACEMENTS_FILE = 'packager_text_replacements_config.json'


def load_config():
    """
    Load configuration from JSON file.
    
    Note: Configuration structure is validated by tests using JSON schema.
    See tests/packager_sources_config_schema.json and test_validate_config_with_schema().

    Returns:
        configuration dictionary
        
    Raises:
        FileNotFoundError: If config file doesn't exist
        json.JSONDecodeError: If config file contains invalid JSON
    """
    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
        
    except FileNotFoundError as e:
        raise FileNotFoundError(f"Configuration file '{CONFIG_FILE}' not found") from e
    except json.JSONDecodeError as e:
        raise json.JSONDecodeError(f"Invalid JSON in configuration file", e.doc, e.pos) from e

def save_config(config: dict):
    """
    Save configuration to JSON file.

    Args:
        config: Configuration dictionary to save
        
    Raises:
        RuntimeError: If config file cannot be saved
    """
    try:
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
    except Exception as e:
        raise RuntimeError(f"Could not save configuration file: {e}") from e

def load_text_replacements(country_code: str):
    """
    Load text replacement mappings from JSON config file for a specific country.
    
    Args:
        country_code: ISO country code (e.g., 'hr', 'de', 'fr')
        
    Returns:
        Dictionary of regex patterns to replacement strings
    """
    try:
        with open(TEXT_REPLACEMENTS_FILE, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        country_rules = config.get(country_code, {})
        if not country_rules:
            print(f"Warning: No text replacements found for country '{country_code}'")
            return {}
        
        replacements = {}
        
        for abbr, expansion in country_rules.get('abbreviations', {}).items():
            pattern = re.escape(abbr).replace(r'\.', r'\.')
            replacements[rf'\b{pattern}\s*'] = expansion
        
        for typo, correction in country_rules.get('typos', {}).items():
            replacements[rf'\b{typo}\b'] = correction
        
        for _, pattern in country_rules.get('cleanup_patterns', {}).items():
            replacements[pattern] = ''
        
        return replacements
        
    except FileNotFoundError:
        print(f"Warning: {TEXT_REPLACEMENTS_FILE} not found, using empty replacements")
        return {}
    except Exception as e:
        print(f"Warning: Error loading {TEXT_REPLACEMENTS_FILE}: {e}")
        return {}
