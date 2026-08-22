#!/usr/bin/env python3
"""
Add google_product_taxonomy_id property to categories.txt based on wikidata mappings.

This script:
1. Loads the wikidata_mappings.json (google_id -> wikidata_qid)
2. Parses categories.txt to find entries with wikidata:en: property
3. Adds google_product_taxonomy_id:en: property to matching entries
"""

import json
import re
import os

def main():
    # Paths
    base_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(base_dir, '../../..'))
    wikidata_mappings_file = os.path.join(base_dir, 'google_product_taxonomy_data', 'wikidata_mappings.json')
    categories_file = os.path.join(repo_root, 'taxonomies/product/categories.txt')
    output_file = os.path.join(repo_root, 'taxonomies/product/categories.txt')
    
    print(f"Loading wikidata mappings from: {wikidata_mappings_file}")
    
    # Load wikidata mappings (google_id -> wikidata_qid)
    with open(wikidata_mappings_file, 'r', encoding='utf-8') as f:
        wikidata_mappings = json.load(f)
    
    # Create reverse mapping (wikidata_qid -> google_id)
    wikidata_to_google = {}
    for google_id, wikidata_qid in wikidata_mappings.items():
        wikidata_to_google[wikidata_qid] = google_id
    
    print(f"Loaded {len(wikidata_mappings)} wikidata mappings")
    
    # Parse categories.txt
    print(f"Processing categories file: {categories_file}")
    
    with open(categories_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    output_lines = []
    entries_modified = 0
    in_header = True
    current_wikidata = None
    wikidata_line_index = None
    
    for i, line in enumerate(lines):
        # Track if we're still in the header
        if in_header:
            if line.startswith('#'):
                output_lines.append(line)
                continue
            elif line.strip() == '':
                output_lines.append(line)
                continue
            else:
                in_header = False
        
        # Check for wikidata property
        wikidata_match = re.match(r'^wikidata:en:\s*(.+)$', line)
        if wikidata_match:
            current_wikidata = wikidata_match.group(1).strip()
            wikidata_line_index = len(output_lines)
            output_lines.append(line)
            
            # Check if this wikidata ID has a corresponding Google taxonomy ID
            if current_wikidata in wikidata_to_google:
                google_id = wikidata_to_google[current_wikidata]
                
                # Check if the next line already has google_product_taxonomy_id
                has_google_id = False
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    if next_line.startswith('google_product_taxonomy_id:en:'):
                        has_google_id = True
                
                # Add google_product_taxonomy_id if not already present
                if not has_google_id:
                    output_lines.append(f"google_product_taxonomy_id:en: {google_id}\n")
                    entries_modified += 1
            
            current_wikidata = None
            wikidata_line_index = None
        else:
            # Check if this is already a google_product_taxonomy_id line (skip it if updating)
            if line.startswith('google_product_taxonomy_id:en:'):
                # Skip this line as we'll add it after wikidata
                continue
            else:
                output_lines.append(line)
    
    # Write output
    print(f"Writing updated categories to: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        f.writelines(output_lines)
    
    print(f"\nComplete!")
    print(f"  Entries modified: {entries_modified}")
    print(f"  Total wikidata->google mappings available: {len(wikidata_to_google)}")

if __name__ == '__main__':
    main()
