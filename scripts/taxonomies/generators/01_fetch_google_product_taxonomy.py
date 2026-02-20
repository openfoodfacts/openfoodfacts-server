#!/usr/bin/env python3
"""
Fetch Google Product Taxonomy data and translations.

This script downloads:
1. The hierarchical JSON structure from the reference repository
2. Multiple language translations from Google's official taxonomy files

Output: JSON files with the taxonomy structure and translations
"""

import json
import re
import requests
from pathlib import Path
from typing import Dict, List, Tuple

# URLs for the taxonomy data
TAXONOMY_JSON_URL = "https://raw.githubusercontent.com/lubianat/google_product_taxonomy_reference/refs/heads/master/data/taxonomy.json"

# Language-specific taxonomy URLs
LANGUAGE_URLS = {
    'en-US': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt',
    'fr-FR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.fr-FR.txt',
    'de-DE': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.de-DE.txt',
    'es-ES': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.es-ES.txt',
    'en-AU': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-AU.txt',
    'de-AT': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.de-DE.txt',
    'fr-BE': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.fr-FR.txt',
    'nl-BE': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.nl-NL.txt',
    'pt-BR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.pt-BR.txt',
    'en-CA': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-US.txt',
    'fr-CA': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.fr-FR.txt',
    'es-CO': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.es-ES.txt',
    'cs-CZ': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.cs-CZ.txt',
    'da-DK': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.da-DK.txt',
    'en-GB': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-GB.txt',
    'en-IE': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-GB.txt',
    'it-IT': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.it-IT.txt',
    'ja-JP': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.ja-JP.txt',
    'es-MX': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.es-ES.txt',
    'nl-NL': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.nl-NL.txt',
    'en-NZ': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.en-AU.txt',
    'no-NO': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.no-NO.txt',
    'pl-PL': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.pl-PL.txt',
    'pt-BR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.pt-BR.txt',
    'ru-RU': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.ru-RU.txt',
    'sv-SE': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.sv-SE.txt',
    'fr-CH': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.fr-CH.txt',
    'de-CH': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.de-CH.txt',
    'tr-TR': 'https://www.google.com/basepages/producttype/taxonomy-with-ids.tr-TR.txt',
}

# Map locale codes to ISO language codes used in OPF taxonomies
LOCALE_TO_LANG = {
    'en-US': 'en',
    'en-GB': 'en',
    'en-AU': 'en',
    'fr-FR': 'fr',
    'fr-CH': 'fr',
    'de-DE': 'de',
    'de-CH': 'de',
    'es-ES': 'es',
    'it-IT': 'it',
    'it-CH': 'it',
    'nl-NL': 'nl',
    'pt-BR': 'pt',
    'cs-CZ': 'cs',
    'da-DK': 'da',
    'ja-JP': 'ja',
    'no-NO': 'no',
    'pl-PL': 'pl',
    'ru-RU': 'ru',
    'sv-SE': 'sv',
    'tr-TR': 'tr',
}


def fetch_json_taxonomy() -> Dict:
    """Fetch the hierarchical JSON taxonomy structure."""
    print(f"Fetching taxonomy JSON from {TAXONOMY_JSON_URL}")
    response = requests.get(TAXONOMY_JSON_URL)
    response.raise_for_status()
    return response.json()


def parse_translation_line(line: str) -> Tuple[str, str, int]:
    """
    Parse a line from Google's taxonomy-with-ids file.
    
    Format: "123 - Category > Subcategory"
    Returns: (id, name, level) where level is the hierarchy depth
    """
    line = line.rstrip('\n')
    
    # Skip comments
    if line.startswith('#'):
        return None, None, None
    
    # Format: ID - Full > Path > To > Category
    # Use non-backtracking pattern to avoid ReDoS vulnerability
    match = re.match(r'^(\d+)\s*-\s*(.+?)[\r\n]*$', line)
    if not match:
        return None, None, None
    
    cat_id = match.group(1)
    full_path = match.group(2).strip()
    
    # The hierarchy level is the number of ' > ' separators plus 1
    parts = full_path.split(' > ')
    level = len(parts)
    
    # The actual category name is the last part
    name = parts[-1].strip()
    
    return cat_id, name, level


def fetch_translations(locale: str, url: str) -> Dict[str, str]:
    """
    Fetch translations for a specific locale.
    
    Returns: Dict mapping category ID to translated name
    """
    print(f"Fetching translations for {locale} from {url}")
    try:
        response = requests.get(url)
        response.raise_for_status()
        
        # Try to detect encoding - Google's files might be in Latin-1
        # First try UTF-8, fall back to Latin-1 if that fails
        try:
            text = response.content.decode('utf-8')
        except UnicodeDecodeError:
            text = response.content.decode('latin-1')
        
        translations = {}
        for line in text.split('\n'):
            if not line.strip() or line.startswith('#'):
                continue
            
            cat_id, name, level = parse_translation_line(line)
            if cat_id:
                translations[cat_id] = name
        
        print(f"  Found {len(translations)} translations for {locale}")
        return translations
    except Exception as e:
        print(f"  Error fetching {locale}: {e}")
        return {}


def fetch_all_translations() -> Dict[str, Dict[str, str]]:
    """
    Fetch all translations and merge by language code.
    
    Returns: Dict mapping language code to dict of (category_id -> name)
    """
    translations_by_lang = {}
    processed_urls = set()
    
    for locale, url in LANGUAGE_URLS.items():
        # Skip duplicate URLs
        if url in processed_urls:
            continue
        processed_urls.add(url)
        
        # Determine the language code
        # Extract the actual locale from the URL
        url_locale_match = re.search(r'taxonomy-with-ids\.([a-z]{2}-[A-Z]{2})\.txt', url)
        if url_locale_match:
            url_locale = url_locale_match.group(1)
            lang_code = LOCALE_TO_LANG.get(url_locale, url_locale[:2])
        else:
            lang_code = locale[:2]
        
        # Fetch translations
        translations = fetch_translations(locale, url)
        
        # Merge with existing translations for this language
        if lang_code not in translations_by_lang:
            translations_by_lang[lang_code] = {}
        
        for cat_id, name in translations.items():
            if cat_id not in translations_by_lang[lang_code]:
                translations_by_lang[lang_code][cat_id] = name
    
    return translations_by_lang


def main():
    """Main function to fetch and save Google Product Taxonomy data."""
    output_dir = Path(__file__).parent / "google_product_taxonomy_data"
    output_dir.mkdir(exist_ok=True)
    
    # Fetch hierarchical structure
    print("\n=== Fetching hierarchical taxonomy ===")
    taxonomy_json = fetch_json_taxonomy()
    
    json_output = output_dir / "taxonomy_structure.json"
    with open(json_output, 'w', encoding='utf-8') as f:
        json.dump(taxonomy_json, f, indent=2, ensure_ascii=False, sort_keys=True)
    print(f"Saved taxonomy structure to {json_output}")
    
    # Fetch translations
    print("\n=== Fetching translations ===")
    translations = fetch_all_translations()
    
    translations_output = output_dir / "translations.json"
    with open(translations_output, 'w', encoding='utf-8') as f:
        json.dump(translations, f, indent=2, ensure_ascii=False, sort_keys=True)
    print(f"Saved translations to {translations_output}")
    
    # Summary
    print("\n=== Summary ===")
    print(f"Total categories in structure: {len(taxonomy_json)}")
    print(f"Languages with translations: {len(translations)}")
    for lang, trans in sorted(translations.items()):
        print(f"  {lang}: {len(trans)} translations")
    
    print(f"\nData saved to {output_dir}")


if __name__ == "__main__":
    main()
