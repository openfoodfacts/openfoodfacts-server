#!/usr/bin/env python3
"""
Fetch Wikidata mappings for Google Product Categories.

This script queries Wikidata for all entities that have a Google Product Category ID
(property P11302) and creates a mapping file.

Output: JSON file with mappings from Google Product Category ID to Wikidata Q-ID
"""

import json
import requests
import time
from pathlib import Path
from typing import Dict, List

# Wikidata SPARQL endpoint
WIKIDATA_SPARQL_URL = "https://query.wikidata.org/sparql"

# SPARQL query to get all Google Product Category mappings
SPARQL_QUERY = """
SELECT ?item ?itemLabel ?value
WHERE {
  ?item wdt:P11302 ?value .
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en,fr,de,es,it,nl,pt,ru,ja,zh,mul" }
}
"""


def fetch_wikidata_mappings() -> List[Dict]:
    """
    Query Wikidata for Google Product Category mappings.
    
    Returns: List of dicts with 'item', 'itemLabel', and 'value' (GPC ID)
    """
    print("Querying Wikidata for Google Product Category mappings...")
    
    params = {
        'query': SPARQL_QUERY,
        'format': 'json'
    }
    
    headers = {
        'User-Agent': 'OpenProductsFacts/1.0 (https://openfoodfacts.org; contact@openfoodfacts.org)'
    }
    
    try:
        response = requests.get(WIKIDATA_SPARQL_URL, params=params, headers=headers, timeout=60)
        response.raise_for_status()
        
        data = response.json()
        bindings = data.get('results', {}).get('bindings', [])
        
        print(f"Found {len(bindings)} Wikidata mappings")
        return bindings
    
    except requests.exceptions.RequestException as e:
        print(f"Error querying Wikidata: {e}")
        return []


def extract_qid(uri: str) -> str:
    """Extract Wikidata Q-ID from URI."""
    # URI format: http://www.wikidata.org/entity/Q12345
    return uri.split('/')[-1]


def process_mappings(bindings: List[Dict]) -> Dict[str, str]:
    """
    Process Wikidata bindings into a simple mapping.
    
    Returns: Dict mapping Google Product Category ID to Wikidata Q-ID
    """
    mappings = {}
    labels = {}
    
    for binding in bindings:
        gpc_id = binding['value']['value']
        wikidata_uri = binding['item']['value']
        wikidata_qid = extract_qid(wikidata_uri)
        label = binding.get('itemLabel', {}).get('value', '')
        
        mappings[gpc_id] = wikidata_qid
        labels[gpc_id] = label
    
    return mappings, labels


def fetch_additional_wikidata_labels(qids: List[str], languages: List[str]) -> Dict[str, Dict[str, str]]:
    """
    Fetch labels for Wikidata items in multiple languages.
    
    Returns: Dict mapping Q-ID to dict of language -> label
    """
    print(f"Fetching labels for {len(qids)} Wikidata items in {len(languages)} languages...")
    
    labels_by_qid = {}
    
    # Process in batches to avoid query size limits
    batch_size = 100
    for i in range(0, len(qids), batch_size):
        batch = qids[i:i + batch_size]
        
        # Build VALUES clause for the batch
        values_clause = ' '.join([f'wd:{qid}' for qid in batch])
        
        query = f"""
        SELECT ?item ?label ?lang
        WHERE {{
          VALUES ?item {{ {values_clause} }}
          ?item rdfs:label ?label .
          BIND(LANG(?label) AS ?lang)
          FILTER(?lang IN ({', '.join([f'"{lang}"' for lang in languages])}))
        }}
        """
        
        params = {
            'query': query,
            'format': 'json'
        }
        
        headers = {
            'User-Agent': 'OpenProductsFacts/1.0 (https://openfoodfacts.org; contact@openfoodfacts.org)'
        }
        
        try:
            response = requests.get(WIKIDATA_SPARQL_URL, params=params, headers=headers, timeout=60)
            response.raise_for_status()
            
            data = response.json()
            bindings = data.get('results', {}).get('bindings', [])
            
            for binding in bindings:
                qid = extract_qid(binding['item']['value'])
                label = binding['label']['value']
                lang = binding['lang']['value']
                
                if qid not in labels_by_qid:
                    labels_by_qid[qid] = {}
                labels_by_qid[qid][lang] = label
            
            # Be nice to Wikidata servers
            time.sleep(0.5)
            
        except requests.exceptions.RequestException as e:
            print(f"Error fetching labels for batch: {e}")
            continue
    
    return labels_by_qid


def main():
    """Main function to fetch and save Wikidata mappings."""
    output_dir = Path(__file__).parent / "google_product_taxonomy_data"
    output_dir.mkdir(exist_ok=True)
    
    # Fetch mappings
    bindings = fetch_wikidata_mappings()
    
    if not bindings:
        print("No mappings found!")
        return
    
    # Process into simple mapping
    mappings, labels = process_mappings(bindings)
    
    # Save basic mappings
    mappings_output = output_dir / "wikidata_mappings.json"
    with open(mappings_output, 'w', encoding='utf-8') as f:
        json.dump(mappings, f, indent=2, ensure_ascii=False, sort_keys=True)
    print(f"Saved {len(mappings)} mappings to {mappings_output}")
    
    # Save with labels for reference
    mappings_with_labels = {
        gpc_id: {
            'wikidata': qid,
            'label': labels.get(gpc_id, '')
        }
        for gpc_id, qid in mappings.items()
    }
    
    detailed_output = output_dir / "wikidata_mappings_detailed.json"
    with open(detailed_output, 'w', encoding='utf-8') as f:
        json.dump(mappings_with_labels, f, indent=2, ensure_ascii=False, sort_keys=True)
    print(f"Saved detailed mappings to {detailed_output}")
    
    # Optionally fetch multilingual labels
    print("\nFetching multilingual labels from Wikidata...")
    languages = ['en', 'fr', 'de', 'es', 'it', 'nl', 'pt', 'ru', 'ja', 'zh']
    qids = list(mappings.values())
    multilingual_labels = fetch_additional_wikidata_labels(qids, languages)
    
    # Save multilingual labels
    labels_output = output_dir / "wikidata_labels.json"
    with open(labels_output, 'w', encoding='utf-8') as f:
        json.dump(multilingual_labels, f, indent=2, ensure_ascii=False, sort_keys=True)
    print(f"Saved multilingual labels to {labels_output}")
    
    print(f"\n=== Summary ===")
    print(f"Total mappings: {len(mappings)}")
    print(f"Wikidata items with multilingual labels: {len(multilingual_labels)}")


if __name__ == "__main__":
    main()
