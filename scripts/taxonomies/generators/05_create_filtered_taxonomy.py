#!/usr/bin/env python3
"""
Create a filtered version of the generated taxonomy.

This script:
1. Removes food, pet food, and cosmetic categories
2. Attempts to match ImpactCO2 entries to Google Product Taxonomy categories
"""

import json
import re
from pathlib import Path
from typing import Dict, Set, List, Optional


def load_json(filepath: Path) -> Dict:
    """Load JSON file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)


def normalize_for_matching(text: str) -> str:
    """Normalize text for fuzzy matching."""
    text = text.lower()
    text = re.sub(r'[^\w\s]', ' ', text)
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def get_all_category_descendants(cat_id: str, taxonomy_structure: Dict[str, Dict]) -> Set[str]:
    """Get all descendant category IDs for a given category."""
    descendants = {cat_id}
    
    if cat_id in taxonomy_structure:
        for child_id in taxonomy_structure[cat_id].get('children', []):
            descendants.update(get_all_category_descendants(child_id, taxonomy_structure))
    
    return descendants


def build_category_structure(taxonomy_json: Dict) -> Dict[str, Dict]:
    """Build category hierarchy from taxonomy JSON."""
    categories = {}
    
    def process_node(node: Dict, parent_id: Optional[str] = None):
        cat_id = str(node.get('google_id', node.get('id', '')))
        name = node.get('name', '')
        
        if not cat_id or cat_id == '0':
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
        
        if 'children' in node:
            for child in node['children']:
                child_id = str(child.get('google_id', child.get('id', '')))
                if child_id and child_id != '0':
                    process_node(child, cat_id)
                    categories[cat_id]['children'].append(child_id)
    
    if isinstance(taxonomy_json, list):
        for root in taxonomy_json:
            process_node(root)
    elif isinstance(taxonomy_json, dict):
        process_node(taxonomy_json)
    
    return categories


def find_matching_category(
    carbon_name: str,
    translations: Dict[str, Dict[str, str]],
    taxonomy_structure: Dict[str, Dict],
    excluded_ids: Set[str]
) -> Optional[str]:
    """Try to find a matching category for a carbon impact entry."""
    normalized_search = normalize_for_matching(carbon_name)
    search_words = set(normalized_search.split())
    
    # Manual mappings for better accuracy
    manual_mappings = {
        'smartphone': '267',  # Mobile Phones
        'smartphones': '267',
        'mobile phone': '267',
        'basic phone': '267',
        'laptop': '328',  # Laptops
        'laptop computer': '328',
        'digital tablet': '4745',  # Tablet Computers
        'digital tablets': '4745',
        'tablet computer': '4745',
        'television': '404',  # Televisions
        'tv': '404',
        'computer screen': '305',  # Computer Monitors
        'monitor': '305',
        'desktop computer': '325',  # Desktop Computers
        'desktop computer without screen personal': '325',
        'desktop computer without screen professional': '325',
        'bed': '505764',  # Beds & Bed Frames
        'chair': '443',  # Chairs
        'wooden chair': '443',
        'table': '6392',  # Tables
        'wooden table': '6392',
        'sofa': '460',  # Sofas
        'textile sofa': '460',
        'convertible sofa': '460',
        'wardrobe': '4063',  # Armoires & Wardrobes
        'refrigerator': '686',  # Refrigerators
        'washing machine': '2549',  # Washing Machines
        'dishwasher': '680',  # Dishwashers
        'vacuum cleaner': '619',  # Vacuums
        'electric oven': '683',  # Ovens
        'oven': '683',
        'kettle': '751',  # Electric Kettles
        'coffee maker': '1388',  # Drip Coffee Makers
        'filter coffee maker': '1388',
        'espresso machine': '3988',  # Coffee Maker & Espresso Machine Accessories
        'pod coffee machine': '3988',
        'air conditioner': '605',  # Air Conditioners
        'external hard drive': '380',  # Hard Drives
        'hard drive': '380',
        'usb key': '3712',  # USB Flash Drives
        'usb flash drive': '3712',
        't shirt': '212',  # Shirts & Tops
        'shirt': '212',
        'cotton shirt': '212',
        'cotton t shirt': '212',
        'sweatshirt': '5322',  # Sweatshirts & Hoodies
        'sweater': '5322',
        'acrylic sweater': '5322',
        'cotton sweatshirt': '5322',
        'dress': '2271',  # Dresses
        'cotton dress': '2271',
        'coat': '5598',  # Coats & Jackets
        'jacket': '5598',
        'faux leather jacket': '5598',
        'shoes': '187',  # Shoes
        'sport shoes': '187',
        'fabric shoes': '187',
        'leather shoes': '187',
        'router': '351',  # Need to verify
        'smartphone external power supply': '5274',  # Power supplies
        'laptop external power supply': '5274',
    }
    
    # Check manual mappings first
    if normalized_search in manual_mappings:
        cat_id = manual_mappings[normalized_search]
        if cat_id not in excluded_ids:
            return cat_id
    
    # Try to find matches in English translations
    best_match = None
    best_score = 0
    
    for cat_id, cat_name in translations.get('en', {}).items():
        if cat_id in excluded_ids:
            continue
        
        normalized_cat = normalize_for_matching(cat_name)
        
        # Exact match
        if normalized_search == normalized_cat:
            return cat_id
        
        # Check if all search words are in the category name
        cat_words = set(normalized_cat.split())
        
        if search_words and cat_words:
            # Check if all key words from search are in category
            common_words = search_words & cat_words
            
            # If most search words match, it's a good candidate
            if len(common_words) >= min(2, len(search_words)):
                score = len(common_words) / len(search_words)
                
                # Prefer shorter category names (more specific)
                specificity_bonus = 1.0 / (1.0 + len(cat_words) / 10.0)
                score = score * (1.0 + specificity_bonus * 0.2)
                
                if score > best_score:
                    best_score = score
                    best_match = cat_id
    
    # Only return if score is reasonable
    if best_score > 0.5:
        return best_match
    
    return None


def filter_taxonomy(
    input_file: Path,
    output_file: Path,
    taxonomy_structure: Dict[str, Dict],
    translations: Dict[str, Dict[str, str]],
    carbon_data: Dict[str, Dict],
    excluded_root_ids: List[str]
):
    """Filter the taxonomy file to remove excluded categories."""
    
    # Get all IDs to exclude (including descendants)
    excluded_ids = set()
    for root_id in excluded_root_ids:
        excluded_ids.update(get_all_category_descendants(root_id, taxonomy_structure))
    
    print(f"Excluding {len(excluded_ids)} categories (including descendants)")
    
    # Try to match carbon impact data to non-excluded categories
    carbon_matches = {}
    for carbon_name, carbon_info in carbon_data.items():
        match_id = find_matching_category(carbon_name, translations, taxonomy_structure, excluded_ids)
        if match_id:
            carbon_matches[match_id] = {
                'original_name': carbon_name,
                'impact': carbon_info.get('impact', ''),
                'link': carbon_info.get('link', ''),
                'unit_name': carbon_info.get('unit_name', {})
            }
            print(f"Matched '{carbon_name}' -> Category {match_id}: {translations['en'].get(match_id, 'N/A')}")
    
    print(f"\nMatched {len(carbon_matches)} carbon impact entries to categories")
    
    # Parse and filter the taxonomy
    current_category_id = None
    current_block = []
    skip_current = False
    categories_written = 0
    categories_skipped = 0
    pending_parent_line = None  # Hold parent relationship for next entry
    
    with open(input_file, 'r', encoding='utf-8') as fin:
        with open(output_file, 'w', encoding='utf-8') as fout:
            # Write header
            fout.write("# Categories taxonomy for Open Products Facts\n")
            fout.write("# Generated from Google Product Taxonomy (filtered version)\n")
            fout.write("# Excludes: Food, Beverages & Tobacco; Animals & Pet Supplies; Health & Beauty\n")
            fout.write("#\n")
            fout.write("# Properties:\n")
            fout.write("#\n")
            fout.write("# - unit_name:en: Name of 1 product unit\n")
            fout.write("# - carbon_impact_fr_impactco2:en: CO2 equivalent in kg per unit\n")
            fout.write("# - carbon_impact_fr_impactco2_link:en: URL on https://impactco2.fr/\n")
            fout.write("# - wikidata:en: Wikidata Q-ID for the category\n")
            fout.write("#\n\n")
            
            in_header = True
            for line in fin:
                # Skip header comments
                if line.startswith('#'):
                    continue
                
                # First non-comment line means header is over
                if line.strip() and in_header:
                    in_header = False
                
                # Skip empty lines in header section
                if in_header and not line.strip():
                    continue
                
                # Check for parent relationship - hold it for next entry
                if line.startswith('<'):
                    # Extract parent category name
                    # Use non-backtracking pattern to avoid ReDoS vulnerability
                    match = re.match(r'^<+\s*([a-z]{2}):?\s*(.+?)[\r\n]*$', line)
                    if match:
                        parent_name = match.group(2).strip()
                        
                        # Find parent ID
                        parent_id = None
                        for cat_id, cat_name in translations.get('en', {}).items():
                            if cat_name == parent_name:
                                parent_id = cat_id
                                break
                        
                        # If parent is excluded, the next category should be skipped
                        if parent_id and parent_id in excluded_ids:
                            pending_parent_line = None  # Don't carry forward excluded parent
                            skip_current = True  # Mark to skip next category
                        else:
                            # Hold parent line with its preceding blank line for next entry
                            pending_parent_line = line
                    continue
                
                # Check if this is a new category (starts with "en:")
                if line.startswith('en:'):
                    # Process previous block if any
                    if current_block and not skip_current:
                        # Remove trailing blank lines temporarily
                        while current_block and current_block[-1].strip() == '':
                            current_block.pop()
                        
                        # Add carbon impact data if matched
                        if current_category_id and current_category_id in carbon_matches:
                            carbon = carbon_matches[current_category_id]
                            if carbon['impact']:
                                current_block.append(f"carbon_impact_fr_impactco2:en: {carbon['impact']}\n")
                            if carbon['link']:
                                current_block.append(f"carbon_impact_fr_impactco2_link:en: {carbon['link']}\n")
                            for lang, unit in carbon.get('unit_name', {}).items():
                                current_block.append(f"unit_name:{lang}: {unit}\n")
                        
                        # Add back a single blank line at the end
                        current_block.append('\n')
                        
                        # Write the block
                        fout.writelines(current_block)
                        categories_written += 1
                    elif skip_current:
                        categories_skipped += 1
                    
                    # Start new block
                    current_block = []
                    
                    # Add pending parent line if any
                    if pending_parent_line:
                        # Don't add extra blank line - it's already in previous block
                        current_block.append(pending_parent_line)
                        current_block.append('\n')  # Blank line after parent
                        pending_parent_line = None
                    
                    # Extract category name to find its ID
                    en_name = line.split(':', 1)[1].strip().split(',')[0].strip()
                    
                    # Find category ID
                    current_category_id = None
                    for cat_id, cat_name in translations.get('en', {}).items():
                        if cat_name == en_name:
                            current_category_id = cat_id
                            break
                    
                    # Check if this category should be excluded
                    if current_category_id in excluded_ids:
                        skip_current = True
                        continue
                    else:
                        skip_current = False  # Reset skip flag for new category
                
                # Add line to current block (except blank lines before parent relationships)
                if not skip_current and not line.startswith('<'):
                    current_block.append(line)
            
            # Don't forget the last block
            if current_block and not skip_current:
                # Remove trailing blank lines temporarily
                while current_block and current_block[-1].strip() == '':
                    current_block.pop()
                
                # Add carbon impact data if matched
                if current_category_id and current_category_id in carbon_matches:
                    carbon = carbon_matches[current_category_id]
                    if carbon['impact']:
                        current_block.append(f"carbon_impact_fr_impactco2:en: {carbon['impact']}\n")
                    if carbon['link']:
                        current_block.append(f"carbon_impact_fr_impactco2_link:en: {carbon['link']}\n")
                    for lang, unit in carbon.get('unit_name', {}).items():
                        current_block.append(f"unit_name:{lang}: {unit}\n")
                
                # Add back a single blank line at the end
                current_block.append('\n')
                
                fout.writelines(current_block)
                categories_written += 1
    
    print(f"\nFiltering complete:")
    print(f"  Categories written: {categories_written}")
    print(f"  Categories skipped: {categories_skipped}")


def main():
    """Main function to create filtered taxonomy."""
    data_dir = Path(__file__).parent / "google_product_taxonomy_data"
    
    print("Loading data...")
    taxonomy_json = load_json(data_dir / 'taxonomy_structure.json')
    translations = load_json(data_dir / 'translations.json')
    carbon_data = load_json(data_dir / 'existing_carbon_impact_data.json')
    
    print("Building category structure...")
    taxonomy_structure = build_category_structure(taxonomy_json)
    print(f"Total categories: {len(taxonomy_structure)}")
    
    # Categories to exclude (root IDs)
    excluded_root_ids = [
        '412',  # Food, Beverages & Tobacco
        '1',    # Animals & Pet Supplies (includes pet food)
        '469',  # Health & Beauty (includes cosmetics)
    ]
    
    print(f"\nExcluding root categories:")
    for cat_id in excluded_root_ids:
        if cat_id in taxonomy_structure:
            print(f"  {cat_id}: {taxonomy_structure[cat_id]['name']}")
    
    input_file = data_dir / 'new_categories.txt'
    output_file = data_dir / 'new_categories_filtered.txt'
    
    print(f"\nFiltering taxonomy...")
    print(f"  Input: {input_file}")
    print(f"  Output: {output_file}")
    print()
    
    filter_taxonomy(
        input_file,
        output_file,
        taxonomy_structure,
        translations,
        carbon_data,
        excluded_root_ids
    )
    
    print(f"\nFiltered taxonomy saved to: {output_file}")


if __name__ == "__main__":
    main()
