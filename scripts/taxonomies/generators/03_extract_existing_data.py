#!/usr/bin/env python3
"""
Extract data from existing categories.txt taxonomy.

This script parses the existing Open Products Facts categories taxonomy to extract:
- Wikidata IDs
- Carbon impact data (from ImpactCO2)
- Additional translations
- Other properties

Output: JSON file with extracted data organized by category
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Tuple, Optional


def parse_taxonomy_file(filepath: str) -> Dict[str, Dict]:
    """
    Parse the categories.txt taxonomy file.
    
    Returns: Dict mapping English category name to its data (translations, properties, etc.)
    """
    categories = {}
    current_category = None
    current_data = {}
    parent_hierarchy = []  # Stack to track parent relationships
    
    with open(filepath, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.rstrip('\n')
            
            # Skip empty lines and comments
            if not line.strip() or line.startswith('#'):
                continue
            
            # Check for parent indicator
            if line.startswith('<'):
                # Parse parent relationship: "< en: Parent Category" or "< en:Parent Category"
                # Use non-backtracking pattern to avoid ReDoS vulnerability
                match = re.match(r'^<+\s*([a-z]{2}(?:-[A-Z]{2})?):?\s*(.+?)[\r\n]*$', line)
                if match:
                    lang = match.group(1)
                    parent_name = match.group(2).strip()
                    level = line.count('<')
                    
                    # Update parent hierarchy
                    parent_hierarchy = parent_hierarchy[:level-1]
                    parent_hierarchy.append(parent_name)
                continue
            
            # Parse property or translation line: "lang: value" or "property:lang: value"
            # Properties can contain letters, numbers, and underscores
            match = re.match(r'^([a-z_0-9]+(?::[a-z]{2}(?:-[A-Z]{2})?)?):?\s*(.*)$', line)
            if not match:
                continue
            
            key_part = match.group(1)
            value = match.group(2).strip()
            
            # Skip if this is just whitespace
            if not value:
                continue
            
            # The key might be "lang" or "property:lang"
            if ':' in key_part:
                key = key_part
            else:
                # This is a simple language code
                key = key_part
            
            # Check if this is a property (contains a colon) or a translation
            if ':' in key:
                # Property like "wikidata:en" or "carbon_impact_fr_impactco2:en"
                parts = key.split(':', 1)
                prop_name = parts[0]
                lang = parts[1] if len(parts) > 1 else 'en'
                
                if current_category:
                    if 'properties' not in current_data:
                        current_data['properties'] = {}
                    if prop_name not in current_data['properties']:
                        current_data['properties'][prop_name] = {}
                    current_data['properties'][prop_name][lang] = value
            else:
                # This is a translation: "en: Category Name"
                lang = key
                
                # If this is an English entry, it might be a new category
                if lang == 'en':
                    # Save previous category if exists
                    if current_category:
                        categories[current_category] = current_data
                    
                    # Start new category
                    # Use the first synonym as the main name
                    synonyms = [s.strip() for s in value.split(',')]
                    current_category = synonyms[0]
                    current_data = {
                        'en': synonyms,
                        'parents': parent_hierarchy.copy() if parent_hierarchy else [],
                        'translations': {}
                    }
                else:
                    # This is a translation in another language
                    if current_category:
                        synonyms = [s.strip() for s in value.split(',')]
                        current_data['translations'][lang] = synonyms
    
    # Don't forget to save the last category
    if current_category:
        categories[current_category] = current_data
    
    return categories


def extract_wikidata_mappings(categories: Dict[str, Dict]) -> Dict[str, str]:
    """
    Extract Wikidata ID mappings from categories.
    
    Returns: Dict mapping category name to Wikidata Q-ID
    """
    wikidata_mappings = {}
    
    for category_name, data in categories.items():
        if 'properties' in data and 'wikidata' in data['properties']:
            wikidata_id = data['properties']['wikidata'].get('en', '')
            if wikidata_id:
                wikidata_mappings[category_name] = wikidata_id
    
    return wikidata_mappings


def extract_carbon_impact_data(categories: Dict[str, Dict]) -> Dict[str, Dict]:
    """
    Extract carbon impact data from categories.
    
    Returns: Dict mapping category name to carbon impact data
    """
    carbon_data = {}
    
    for category_name, data in categories.items():
        if 'properties' not in data:
            continue
        
        props = data['properties']
        if 'carbon_impact_fr_impactco2' in props or 'carbon_impact_fr_impactco2_link' in props:
            carbon_data[category_name] = {
                'impact': props.get('carbon_impact_fr_impactco2', {}).get('en', ''),
                'link': props.get('carbon_impact_fr_impactco2_link', {}).get('en', ''),
                'unit_name': props.get('unit_name', {})
            }
    
    return carbon_data


def extract_all_properties(categories: Dict[str, Dict]) -> Dict[str, Dict]:
    """
    Extract all properties from categories for reuse.
    
    Returns: Dict mapping category name to all its properties
    """
    properties_data = {}
    
    for category_name, data in categories.items():
        if 'properties' in data:
            properties_data[category_name] = data['properties']
    
    return properties_data


def main():
    """Main function to extract data from existing taxonomy."""
    # Path to the existing taxonomy
    taxonomy_path = Path(__file__).parent.parent.parent.parent / "taxonomies" / "product" / "categories.txt"
    
    if not taxonomy_path.exists():
        print(f"Error: Cannot find taxonomy file at {taxonomy_path}")
        return
    
    print(f"Parsing taxonomy file: {taxonomy_path}")
    categories = parse_taxonomy_file(str(taxonomy_path))
    print(f"Found {len(categories)} categories")
    
    # Create output directory
    output_dir = Path(__file__).parent / "google_product_taxonomy_data"
    output_dir.mkdir(exist_ok=True)
    
    # Extract and save full category data
    full_output = output_dir / "existing_categories_data.json"
    with open(full_output, 'w', encoding='utf-8') as f:
        json.dump(categories, f, indent=2, ensure_ascii=False, sort_keys=True)
    print(f"Saved full category data to {full_output}")
    
    # Extract Wikidata mappings
    wikidata_mappings = extract_wikidata_mappings(categories)
    wikidata_output = output_dir / "existing_wikidata_mappings.json"
    with open(wikidata_output, 'w', encoding='utf-8') as f:
        json.dump(wikidata_mappings, f, indent=2, ensure_ascii=False, sort_keys=True)
    print(f"Saved {len(wikidata_mappings)} Wikidata mappings to {wikidata_output}")
    
    # Extract carbon impact data
    carbon_data = extract_carbon_impact_data(categories)
    carbon_output = output_dir / "existing_carbon_impact_data.json"
    with open(carbon_output, 'w', encoding='utf-8') as f:
        json.dump(carbon_data, f, indent=2, ensure_ascii=False, sort_keys=True)
    print(f"Saved {len(carbon_data)} carbon impact entries to {carbon_output}")
    
    # Extract all properties
    properties_data = extract_all_properties(categories)
    properties_output = output_dir / "existing_properties.json"
    with open(properties_output, 'w', encoding='utf-8') as f:
        json.dump(properties_data, f, indent=2, ensure_ascii=False, sort_keys=True)
    print(f"Saved properties for {len(properties_data)} categories to {properties_output}")
    
    print("\n=== Summary ===")
    print(f"Total categories: {len(categories)}")
    print(f"Categories with Wikidata IDs: {len(wikidata_mappings)}")
    print(f"Categories with carbon impact data: {len(carbon_data)}")


if __name__ == "__main__":
    main()
