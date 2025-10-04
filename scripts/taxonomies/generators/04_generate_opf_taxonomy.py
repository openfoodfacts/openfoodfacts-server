#!/usr/bin/env python3
"""
Generate OPF categories taxonomy from Google Product Taxonomy.

This script combines:
1. Google Product Taxonomy structure and translations
2. Wikidata mappings (Google Product Category ID -> Wikidata Q-ID)
3. Existing OPF category data (carbon impact, additional translations, etc.)

Output: New categories.txt file in OPF taxonomy format
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Optional, Set


def load_json(filepath: Path) -> Dict:
    """Load JSON file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)


def normalize_category_name(name: str) -> str:
    """Normalize category name for matching."""
    # Convert to lowercase and remove extra spaces
    name = name.lower().strip()
    # Replace multiple spaces with single space
    name = re.sub(r'\s+', ' ', name)
    return name


def find_matching_existing_category(
    gpc_name: str,
    existing_categories: Dict[str, Dict]
) -> Optional[str]:
    """
    Try to find a matching category in existing data.
    
    This uses fuzzy matching on normalized names.
    """
    normalized_gpc = normalize_category_name(gpc_name)
    
    # Try exact match first
    for cat_name in existing_categories.keys():
        if normalize_category_name(cat_name) == normalized_gpc:
            return cat_name
    
    # Try matching with any synonym
    for cat_name, data in existing_categories.items():
        # Check English synonyms
        if 'en' in data:
            for synonym in data['en']:
                if normalize_category_name(synonym) == normalized_gpc:
                    return cat_name
        
        # Check other language translations
        if 'translations' in data:
            for lang, synonyms in data['translations'].items():
                for synonym in synonyms:
                    if normalize_category_name(synonym) == normalized_gpc:
                        return cat_name
    
    return None


def build_category_hierarchy(taxonomy_structure: Dict) -> Dict[str, Dict]:
    """
    Build a hierarchical structure from the Google Product Taxonomy.
    
    Returns: Dict mapping category ID to its data including parent relationships
    """
    categories = {}
    
    def process_node(node: Dict, parent_id: Optional[str] = None):
        """Recursively process taxonomy nodes."""
        cat_id = str(node.get('google_id', node.get('id', '')))
        name = node.get('name', '')
        
        if not cat_id or cat_id == '0':  # Skip root node
            # Process children of root
            if 'children' in node:
                for child in node['children']:
                    process_node(child, None)
            return
        
        categories[cat_id] = {
            'id': cat_id,
            'name': name,
            'parent_id': parent_id,
            'children': []
        }
        
        # Process children
        if 'children' in node:
            for child in node['children']:
                child_id = str(child.get('google_id', child.get('id', '')))
                if child_id and child_id != '0':
                    process_node(child, cat_id)
                    categories[cat_id]['children'].append(child_id)
    
    # Process all root nodes
    if isinstance(taxonomy_structure, list):
        for root in taxonomy_structure:
            process_node(root)
    elif isinstance(taxonomy_structure, dict):
        process_node(taxonomy_structure)
    
    return categories


def merge_translations(
    cat_id: str,
    gpc_translations: Dict[str, Dict[str, str]],
    existing_data: Optional[Dict] = None
) -> Dict[str, List[str]]:
    """
    Merge translations from Google Product Taxonomy and existing OPF data.
    
    Returns: Dict mapping language code to list of synonyms
    """
    merged = {}
    
    # Add Google Product Taxonomy translations
    for lang, translations in gpc_translations.items():
        if cat_id in translations:
            name = translations[cat_id]
            if lang not in merged:
                merged[lang] = []
            if name not in merged[lang]:
                merged[lang].append(name)
    
    # Add existing translations if available
    if existing_data:
        # Add English synonyms
        if 'en' in existing_data:
            if 'en' not in merged:
                merged['en'] = []
            for synonym in existing_data['en']:
                if synonym not in merged['en']:
                    merged['en'].append(synonym)
        
        # Add other language translations
        if 'translations' in existing_data:
            for lang, synonyms in existing_data['translations'].items():
                if lang not in merged:
                    merged[lang] = []
                for synonym in synonyms:
                    if synonym not in merged[lang]:
                        merged[lang].append(synonym)
    
    return merged


def format_taxonomy_entry(
    cat_id: str,
    category_data: Dict,
    translations: Dict[str, List[str]],
    parent_id: Optional[str],
    wikidata_id: Optional[str] = None,
    carbon_data: Optional[Dict] = None,
    properties: Optional[Dict] = None,
    parent_names: Optional[Dict[str, str]] = None
) -> str:
    """
    Format a single taxonomy entry in OPF format.
    
    Returns: Formatted string for the taxonomy file
    """
    lines = []
    
    # Add parent relationship if exists
    if parent_id and parent_names and 'en' in parent_names:
        parent_name = parent_names['en']
        lines.append(f"< en: {parent_name}")
        lines.append("")
    
    # Add translations, starting with English
    if 'en' in translations:
        en_synonyms = ', '.join(translations['en'])
        lines.append(f"en: {en_synonyms}")
    
    # Add 'xx' for international synonyms if applicable
    # Use 'xx' when the term is the same across languages
    if 'en' in translations and len(translations['en']) > 0:
        main_name = translations['en'][0]
        # Check if name is likely a brand/international term
        if main_name and (main_name[0].isupper() or len(main_name.split()) <= 2):
            lines.append(f"xx: {main_name}")
    
    # Add other language translations in alphabetical order
    for lang in sorted(translations.keys()):
        if lang != 'en':
            synonyms = ', '.join(translations[lang])
            lines.append(f"{lang}: {synonyms}")
    
    # Add properties
    if wikidata_id:
        lines.append(f"wikidata:en: {wikidata_id}")
    
    if carbon_data:
        if carbon_data.get('impact'):
            lines.append(f"carbon_impact_fr_impactco2:en: {carbon_data['impact']}")
        if carbon_data.get('link'):
            lines.append(f"carbon_impact_fr_impactco2_link:en: {carbon_data['link']}")
        if carbon_data.get('unit_name'):
            for lang, unit in carbon_data['unit_name'].items():
                lines.append(f"unit_name:{lang}: {unit}")
    
    if properties:
        for prop_name, prop_values in sorted(properties.items()):
            # Skip properties we've already handled
            if prop_name in ['wikidata', 'carbon_impact_fr_impactco2', 
                           'carbon_impact_fr_impactco2_link', 'unit_name']:
                continue
            for lang, value in sorted(prop_values.items()):
                lines.append(f"{prop_name}:{lang}: {value}")
    
    return '\n'.join(lines)


def generate_taxonomy(
    taxonomy_structure: Dict[str, Dict],
    gpc_translations: Dict[str, Dict[str, str]],
    wikidata_mappings: Dict[str, str],
    existing_categories: Dict[str, Dict],
    output_file: Path
):
    """
    Generate the complete taxonomy file.
    """
    print("Generating taxonomy...")
    
    # Build lookup for category names by ID
    category_names = {}
    for cat_id, data in taxonomy_structure.items():
        if 'en' in gpc_translations and cat_id in gpc_translations['en']:
            category_names[cat_id] = gpc_translations['en'][cat_id]
        else:
            category_names[cat_id] = data.get('name', f'Category {cat_id}')
    
    with open(output_file, 'w', encoding='utf-8') as f:
        # Write header
        f.write("# Categories taxonomy for Open Products Facts\n")
        f.write("# Generated from Google Product Taxonomy\n")
        f.write("#\n")
        f.write("# Properties:\n")
        f.write("#\n")
        f.write("# - unit_name:en: Name of 1 product unit, e.g. for the category \"Books\" -> \"book\". Used in particular for carbon footprint equivalent: 1 smartphone = 85.9 kg CO2e\n")
        f.write("#\n")
        f.write("# - carbon_impact_fr_impactco2:en: co2 equivalent in kg per unit (1 product) from https://impactco2.fr/\n")
        f.write("# - carbon_impact_fr_impactco2_link:en: URL for the category on https://impactco2.fr/\n")
        f.write("#\n")
        f.write("# - wikidata:en: Wikidata Q-ID for the category\n")
        f.write("#\n")
        f.write("\n")
        
        # Process categories in order (root first, then children)
        processed = set()
        
        def write_category(cat_id: str, depth: int = 0):
            """Recursively write category and its children."""
            if cat_id in processed:
                return
            processed.add(cat_id)
            
            data = taxonomy_structure[cat_id]
            
            # Get translations
            translations = merge_translations(cat_id, gpc_translations)
            
            # Try to find matching existing category
            if 'en' in translations and translations['en']:
                main_name = translations['en'][0]
                existing_match = find_matching_existing_category(main_name, existing_categories)
                if existing_match:
                    existing_data = existing_categories[existing_match]
                    # Merge with existing data
                    translations = merge_translations(cat_id, gpc_translations, existing_data)
                else:
                    existing_data = None
            else:
                existing_data = None
            
            # Get Wikidata ID
            wikidata_id = wikidata_mappings.get(cat_id)
            
            # Get carbon impact data
            carbon_data = None
            properties = None
            if existing_data:
                if 'properties' in existing_data:
                    props = existing_data['properties']
                    if 'carbon_impact_fr_impactco2' in props or 'carbon_impact_fr_impactco2_link' in props:
                        carbon_data = {
                            'impact': props.get('carbon_impact_fr_impactco2', {}).get('en', ''),
                            'link': props.get('carbon_impact_fr_impactco2_link', {}).get('en', ''),
                            'unit_name': props.get('unit_name', {})
                        }
                    properties = props
            
            # Get parent name for relationship
            parent_names = None
            if data.get('parent_id'):
                parent_id = data['parent_id']
                parent_names = {}
                for lang, trans in gpc_translations.items():
                    if parent_id in trans:
                        parent_names[lang] = trans[parent_id]
            
            # Format and write entry
            entry = format_taxonomy_entry(
                cat_id,
                data,
                translations,
                data.get('parent_id'),
                wikidata_id,
                carbon_data,
                properties,
                parent_names
            )
            
            if entry:
                f.write(entry)
                f.write('\n\n')
            
            # Write children
            for child_id in data.get('children', []):
                write_category(child_id, depth + 1)
        
        # Find and write root categories first
        root_categories = [cat_id for cat_id, data in taxonomy_structure.items() 
                          if not data.get('parent_id')]
        
        for cat_id in sorted(root_categories):
            write_category(cat_id)
    
    print(f"Generated taxonomy with {len(processed)} categories")
    print(f"Saved to {output_file}")


def main():
    """Main function to generate the taxonomy."""
    data_dir = Path(__file__).parent / "google_product_taxonomy_data"
    
    # Check if data files exist
    required_files = [
        'taxonomy_structure.json',
        'translations.json',
        'wikidata_mappings.json',
        'existing_categories_data.json'
    ]
    
    for filename in required_files:
        filepath = data_dir / filename
        if not filepath.exists():
            print(f"Error: Required file not found: {filepath}")
            print("Please run the data fetching scripts first:")
            print("  1. 01_fetch_google_product_taxonomy.py")
            print("  2. 02_fetch_wikidata_mappings.py")
            print("  3. 03_extract_existing_data.py")
            return
    
    # Load data
    print("Loading data...")
    taxonomy_structure_raw = load_json(data_dir / 'taxonomy_structure.json')
    gpc_translations = load_json(data_dir / 'translations.json')
    wikidata_mappings = load_json(data_dir / 'wikidata_mappings.json')
    existing_categories = load_json(data_dir / 'existing_categories_data.json')
    
    # Build hierarchy
    print("Building category hierarchy...")
    taxonomy_structure = build_category_hierarchy(taxonomy_structure_raw)
    print(f"Found {len(taxonomy_structure)} categories in hierarchy")
    
    # Generate taxonomy
    output_file = data_dir / "new_categories.txt"
    generate_taxonomy(
        taxonomy_structure,
        gpc_translations,
        wikidata_mappings,
        existing_categories,
        output_file
    )
    
    print("\n=== Done ===")
    print(f"New taxonomy file: {output_file}")
    print("\nTo use this taxonomy, review it and then copy to:")
    print("  taxonomies/product/categories.txt")


if __name__ == "__main__":
    main()
