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
Reusable geocoding simplification strategies.

Each strategy is a function that takes (country_name, params, code) and returns modified params,
or None if the strategy doesn't apply (no modification made).

Returning None allows skipping unnecessary retry attempts when a strategy has no effect.
Countries can import and reuse these strategies in their geocode_strategies.py files.
"""

import re

# STREET STRATEGIES

def strategy_split_street_comma(country_name: str, params: dict, code: str) -> dict:
    """Remove text after comma in street (e.g., 'Sejerøvej 28, Horsekær' -> 'Sejerøvej 28')
    
    Returns None if no comma is present (no modification).
    """
    if 'street' in params and ',' in params['street']:
        params = params.copy()
        print(f"{country_name} - Warning - {code}: No results found. Retrying with street address before comma")
        params['street'] = params['street'].split(',')[0].strip()
        return params
    return None


def strategy_split_street_last_space(country_name: str, params: dict, code: str) -> dict:
    """Crop street address after the last number (e.g., 'Landströmsgatan 21 Svartsmara' -> 'Landströmsgatan 21')
    
    Returns None if no modification can be made.
    """
    if 'street' in params:
        street = params['street']
        # Find the last sequence of digits
        match = re.search(r'\d+', street)
        if match:
            last_digit_pos = match.end()
            # Crop the string after the last digit
            cropped_street = street[:last_digit_pos].strip()
            if cropped_street != street:  # Only log if a change was made
                params = params.copy()
                print(f"{country_name} - Warning - {code}: No results found. Retrying with cropped street address")
                params['street'] = cropped_street
                return params
    return None


def strategy_remove_street(country_name: str, params: dict, code: str) -> dict:
    """Remove street from parameters
    
    Returns None if street is not present (no modification).
    """
    if 'street' in params:
        params = params.copy()
        print(f"{country_name} - Warning - {code}: No results found. Retrying without street")
        del params['street']
        return params
    return None

# CITY STRATEGIES

def strategy_split_city_hyphen(country_name: str, params: dict, code: str) -> dict:
    """Simplify city name by taking text before hyphen
    
    Returns None if no hyphen is present (no modification).
    """
    if 'city' in params and '-' in params['city']:
        params = params.copy()
        print(f"{country_name} - Warning - {code}: No results found. Retrying with simplified city name (before hyphen)")
        params['city'] = params['city'].split('-')[0]
        return params
    return None

def strategy_remove_city(country_name: str, params: dict, code: str) -> dict:
    """Remove city from parameters
    
    Returns None if city is not present (no modification).
    """
    if 'city' in params:
        params = params.copy()
        print(f"{country_name} - Warning - {code}: No results found. Retrying without city")
        del params['city']
        return params
    return None

def create_strategy_reset_without_city(initial_params: dict):
    """
    Create a strategy that resets to full initial address but without city restrictions.
    
    This factory function is needed because the strategy needs access to initial_params.
    
    Args:
        initial_params: Original parameters with full address
        
    Returns:
        Strategy function
    """
    def strategy_reset_without_city(country_name: str, _params: dict, code: str) -> dict:
        """Reset to full address but remove city restrictions"""
        print(f"{country_name} - Warning - {code}: No results found. Retrying with full address without city restrictions")
        new_params = initial_params.copy()
        new_params.pop('city', None)
        return new_params
                
    return strategy_reset_without_city

# POSTAL CODE STRATEGIES

def strategy_remove_postalcode(country_name: str, params: dict, code: str) -> dict:
    """Remove postal code from parameters
    
    Returns None if postalcode is not present (no modification).
    """
    if 'postalcode' in params:
        params = params.copy()
        print(f"{country_name} - Warning - {code}: No results found. Retrying without postalcode")
        del params['postalcode']
        return params
    return None

# COUNTRY STRATEGIES

def create_strategy_reset_without_country(initial_params: dict):
    """
    Create a strategy that resets to full initial address but without country restrictions.
    
    This factory function is needed because the strategy needs access to initial_params.
    
    Args:
        initial_params: Original parameters with full address
        
    Returns:
        Strategy function
    """
    def strategy_reset_without_country(country_name: str, _params: dict, code: str) -> dict:
        """Reset to full address but remove country restrictions"""
        print(f"{country_name} - Warning - {code}: No results found. Retrying with full address without country restrictions")
        new_params = initial_params.copy()
        new_params.pop('country', None)
        new_params.pop('countrycodes', None)
        return new_params
    
    return strategy_reset_without_country
