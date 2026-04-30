#!/usr/bin/env python3
"""
Add google_product_taxonomy_id property to food, petfood, and beauty taxonomy files
based on wikidata mappings.

This script reads wikidata_mappings.json and adds google_product_taxonomy_id:en:
property to entries that have wikidata:en: properties.
"""

import json
import os
import re

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "google_product_taxonomy_data")
WIKIDATA_MAPPINGS_FILE = os.path.join(DATA_DIR, "wikidata_mappings.json")
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", ".."))

# Taxonomy files to process
TAXONOMY_FILES = [
    os.path.join(REPO_ROOT, "taxonomies", "food", "categories.txt"),
    os.path.join(REPO_ROOT, "taxonomies", "petfood", "categories.txt"),
    os.path.join(REPO_ROOT, "taxonomies", "beauty", "categories.txt"),
]


def load_wikidata_mappings():
    """Load wikidata mappings and create reverse lookup."""
    print(f"Loading wikidata mappings from {WIKIDATA_MAPPINGS_FILE}...")
    
    with open(WIKIDATA_MAPPINGS_FILE, 'r', encoding='utf-8') as f:
        mappings = json.load(f)
    
    # Create reverse lookup: wikidata_id -> google_id
    wikidata_to_google = {}
    for google_id, wikidata_id in mappings.items():
        if wikidata_id:
            wikidata_to_google[wikidata_id] = google_id
    
    print(f"Loaded {len(wikidata_to_google)} wikidata to Google ID mappings")
    return wikidata_to_google


def add_google_taxonomy_ids(taxonomy_file, wikidata_to_google):
    """Add google_product_taxonomy_id to entries with wikidata IDs."""
    
    print(f"\nProcessing {taxonomy_file}...")
    
    # Read the file
    with open(taxonomy_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Process lines
    new_lines = []
    updates_count = 0
    wikidata_count = 0
    
    for i, line in enumerate(lines):
        new_lines.append(line)
        
        # Check if this line has a wikidata property
        if line.strip().startswith('wikidata:en:'):
            wikidata_count += 1
            # Extract the wikidata ID
            match = re.match(r'wikidata:en:\s*(.+)', line.strip())
            if match:
                wikidata_id = match.group(1).strip()
                
                # Check if we have a Google ID for this wikidata ID
                if wikidata_id in wikidata_to_google:
                    google_id = wikidata_to_google[wikidata_id]
                    # Add the google_product_taxonomy_id on the next line
                    new_lines.append(f"google_product_taxonomy_id:en: {google_id}\n")
                    updates_count += 1
    
    # Write back
    with open(taxonomy_file, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"  Found {wikidata_count} wikidata entries")
    print(f"  Added {updates_count} google_product_taxonomy_id entries")
    print(f"  {wikidata_count - updates_count} wikidata entries don't have Google mappings")
    
    return updates_count


def main():
    print("=" * 60)
    print("Adding google_product_taxonomy_id to taxonomy files")
    print("=" * 60)
    
    # Load wikidata mappings
    wikidata_to_google = load_wikidata_mappings()
    
    # Process each taxonomy file
    total_updates = 0
    for taxonomy_file in TAXONOMY_FILES:
        if os.path.exists(taxonomy_file):
            updates = add_google_taxonomy_ids(taxonomy_file, wikidata_to_google)
            total_updates += updates
        else:
            print(f"\nWARNING: File not found: {taxonomy_file}")
    
    print("\n" + "=" * 60)
    print(f"Total google_product_taxonomy_id entries added: {total_updates}")
    print("=" * 60)


if __name__ == "__main__":
    main()
